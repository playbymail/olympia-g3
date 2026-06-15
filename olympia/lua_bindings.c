/*
 *  lua_bindings.c -- olyscript-g3 host + the embedded `oly` Lua module
 *                    (issue #31, the smallest-viable scenario-scripting layer;
 *                    see doc/scripting-tool.md §2, §3, §8, §9).
 *
 *  This is the ONLY translation unit unique to olyscript-g3. It links against
 *  every engine object (compiled with OLYSCRIPT_HOST, which only suppresses
 *  main.c's main() and enables the scenario.h hooks) plus vendored Lua
 *  (lua_vendored). It is OUR code, so it takes the full -Werror modernization
 *  ladder; only the vendored Lua sources are exempt (CMakeLists.txt).
 *
 *  The binding strategy is "parser path (A)" from the design doc: each entity
 *  op formats a command string and runs it through the SAME oly_parse() +
 *  do_command() path immediate mode (-i) uses, so behavior is identical to the
 *  existing GM verbs by construction -- no new game logic lives here. The one
 *  thing the doc identifies as worth adding -- a symbolic-name registry so the
 *  author names entities instead of recovering engine-minted ids by awk -- is
 *  a small host-side table that is NEVER serialized into the game db.
 *
 *  Prototype surface (doc §9): load, extract_startlocs, add_player, poof,
 *  additem, guard, order, save, plus the loc/has_item query reads and the
 *  name/id registry. Everything else in the design (make_loc, know, kill,
 *  credit, the wider query set, the declarative format, RNG bindings) is
 *  deferred.
 */

#include <stdio.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "z.h"
#include "oly.h"
#include "scenario.h"


/* -------------------------------------------------------------------------
 *  Symbolic-name registry (doc §2.1).
 *
 *  An author-chosen name ("grok") -> minted id (2355) side table living only
 *  in the scripting host. add_player binds names on create; oly.id() resolves
 *  them; oly.name() reverses. It is deliberately tiny and linear -- a scenario
 *  names a handful of entities, not thousands.
 * ------------------------------------------------------------------------- */

#define REG_MAX 256

static char	*reg_names[REG_MAX];
static int	 reg_ids[REG_MAX];
static int	 reg_count = 0;

static int
reg_lookup(const char *name)
{
	int i;

	for (i = 0; i < reg_count; i++)
		if (strcmp(reg_names[i], name) == 0)
			return reg_ids[i];

	return -1;
}

/*
 *  Bind name -> id. `name` must be a persistently-allocated string (the caller
 *  passes a str_save()'d buffer); the registry takes ownership of it.
 */
static void
reg_bind(char *name, int id)
{
	int i;

	for (i = 0; i < reg_count; i++)
		if (strcmp(reg_names[i], name) == 0)
		{
			reg_ids[i] = id;
			return;
		}

	if (reg_count < REG_MAX)
	{
		reg_names[reg_count] = name;
		reg_ids[reg_count] = id;
		reg_count++;
	}
}


/* -------------------------------------------------------------------------
 *  Lua table-field readers (used by add_player's keyword-table argument).
 * ------------------------------------------------------------------------- */

/*
 *  Read table field `key` as a string and return a persistent copy
 *  (str_save'd). Numbers coerce to strings too (so start = 0 reads as "0").
 *  Returns NULL when the field is absent/nil.
 */
static char *
opt_field_str(lua_State *L, int t, const char *key)
{
	const char *s;
	char *out = NULL;

	lua_getfield(L, t, key);
	if (!lua_isnil(L, -1))
	{
		s = lua_tostring(L, -1);
		if (s != NULL)
			out = str_save((char *) s);
	}
	lua_pop(L, 1);

	return out;
}

static char *
req_field_str(lua_State *L, int t, const char *key)
{
	char *out = opt_field_str(L, t, key);

	if (out == NULL)
		luaL_error(L, "add_player: missing string field '%s'", key);

	return out;
}

static int
req_field_int(lua_State *L, int t, const char *key)
{
	int v;

	lua_getfield(L, t, key);
	if (!lua_isnumber(L, -1))
		luaL_error(L, "add_player: missing/invalid integer field '%s'",
				key);
	v = (int) lua_tointeger(L, -1);
	lua_pop(L, 1);

	return v;
}


/* -------------------------------------------------------------------------
 *  The command bridge: run one immediate-mode command line.
 *
 *  This is immediate_commands()'s per-line body (immed.c) with the stdin loop
 *  removed -- take the current GM context (the global `immediate`, which a
 *  `be` line updates as it runs, exactly as under -i), parse, dispatch, run to
 *  completion. Going through oly_parse()/do_command() is what makes the
 *  bindings byte-for-byte equivalent to -i.
 *
 *  The command struct lives on bx[immediate]->cmd, so a `be <who>` line is
 *  recorded on the OUTGOING context's box and only then switches `immediate`
 *  -- precisely the interleaving the legacy `be/poof/.../save` stream leaves in
 *  the saved db. be_subject() below reproduces that stream so the per-entity
 *  command state matches the committed fixture.
 * ------------------------------------------------------------------------- */

static void
script_cmd(lua_State *L, char *line)
{
	struct command *c;
	char buf[LEN];

	c = p_command(immediate);
	c->who = immediate;
	c->wait = 0;

	strcpy(buf, line);

	if (!oly_parse(c, buf))
	{
		luaL_error(L, "oly: unrecognized command: %s", line);
		return;
	}

	c->pri = (schar) cmd_tbl[c->cmd].pri;
	c->wait = cmd_tbl[c->cmd].time;
	c->poll = (schar) cmd_tbl[c->cmd].poll;
	c->days_executing = 0;
	c->state = STATE_LOAD;

	do_command(c);

	while (c->state == STATE_RUN)
	{
		evening = 1;
		finish_command(c);
		evening = 0;
		olytime_increment(&sysclock);
	}
}

/*
 *  Make `who` the active subject by issuing a real `be <who>` line (a no-op if
 *  already active) -- the under-the-hood `be` of doc §2.3, done as an actual
 *  command so the legacy stream's per-box command state is reproduced exactly.
 */
static void
be_subject(lua_State *L, int who)
{
	if (immediate != who)
		script_cmd(L, sout("be %d", who));
}


/* -------------------------------------------------------------------------
 *  Bindings (the `oly` module functions).
 * ------------------------------------------------------------------------- */

/*
 *  oly.load(libdir [, opts])  -- point at a library and load_db().
 *
 *  call_init_routines() has already run in main(); this is the equivalent of
 *  the engine starting up against an existing lib. The trailing immediate-mode
 *  setup (init_locs_touched / show_day / immediate) mirrors
 *  immediate_commands() so subsequent poof/show_loc behave as under -i.
 *  The optional opts table is accepted for forward-compat (doc §8's
 *  { fixture = ... }) but the prototype ignores it -- fixture extraction is the
 *  regress script's job.
 */
static int
l_load(lua_State *L)
{
	const char *dir = luaL_checkstring(L, 1);

	libdir = str_save((char *) dir);
	load_db();

	init_locs_touched();
	show_day = TRUE;
	immediate = gm_player;

	return 0;
}

/* oly.extract_startlocs()  -- wrap extract_startlocs() (the -s step). */
static int
l_extract_startlocs(lua_State *L)
{
	(void) L;
	extract_startlocs();
	return 0;
}

/*
 *  oly.add_player{ id=, faction=, noble=, noble_name=, start=, full_name=,
 *                  email=, name= }  -> { player = <id>, noble = <id> }
 *
 *  The scripted replacement for guard-pillage steps 3-5 (doc §1.4): mint one
 *  regular faction + starting noble. `id` is the explicit faction box id
 *  (allocated via alloc_box, NO global rnd() draw -- deterministic build
 *  allocation, doc §3.2). The noble is minted by the engine's new_ent() inside
 *  add_new_player(), and its id is captured into the registry under the
 *  author's `noble` handle -- killing the awk id-recovery step. `name` (the
 *  player handle) is bound too when present.
 */
static int
l_add_player(lua_State *L)
{
	int id, noble;
	char *faction, *noble_handle, *noble_name, *start;
	char *full_name, *email, *pname;

	luaL_checktype(L, 1, LUA_TTABLE);

	id           = req_field_int(L, 1, "id");
	faction      = req_field_str(L, 1, "faction");
	noble_handle = req_field_str(L, 1, "noble");
	noble_name   = req_field_str(L, 1, "noble_name");
	start        = req_field_str(L, 1, "start");
	full_name    = req_field_str(L, 1, "full_name");
	email        = req_field_str(L, 1, "email");
	pname        = opt_field_str(L, 1, "name");

	noble = scenario_add_player(id, faction, noble_name, start,
					full_name, email);

	if (noble <= 0)
		return luaL_error(L, "add_player: could not mint faction %d", id);

	/*
	 *  Match the -a pass: its new-player report sorts the faction's and
	 *  noble's item lists ascending-by-id in place, and that order is what
	 *  the saved db records. Do it here -- before any later additem -- since
	 *  the host issues no reports.
	 */
	scenario_sort_items(id);
	scenario_sort_items(noble);

	reg_bind(noble_handle, noble);
	if (pname != NULL)
		reg_bind(pname, id);

	lua_newtable(L);
	lua_pushinteger(L, id);
	lua_setfield(L, -2, "player");
	lua_pushinteger(L, noble);
	lua_setfield(L, -2, "noble");

	return 1;
}

/* oly.poof(who, loc)  -- v_poof: teleport who's stack to a loc/ship. */
static int
l_poof(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int where = (int) luaL_checkinteger(L, 2);

	be_subject(L, who);
	script_cmd(L, sout("poof %d", where));
	return 0;
}

/* oly.additem(who, item, qty)  -- v_add_item / gen_item. */
static int
l_additem(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int item = (int) luaL_checkinteger(L, 2);
	int qty = (int) luaL_checkinteger(L, 3);

	be_subject(L, who);
	script_cmd(L, sout("additem %d %d", item, qty));
	return 0;
}

/* oly.guard(who, on)  -- the `guard` order set via v_guard. */
static int
l_guard(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int on = lua_toboolean(L, 2);

	be_subject(L, who);
	script_cmd(L, on ? sout("guard 1") : sout("guard 0"));
	return 0;
}

/*
 *  oly.order(who, "pillage 1")  -- queue a turn order for who.
 *
 *  queue_order() str_save()'s its argument, and oly.save -> save_db ->
 *  save_orders writes lib/orders/<pl>, so the hand-written order files of the
 *  old flow (doc §1.4 step 7) are generated instead.
 */
static int
l_order(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	const char *order = luaL_checkstring(L, 2);

	queue_order(player(who), who, (char *) order);
	return 0;
}

/*
 *  oly.save([path])  -- freeze the db.
 *
 *  Issued as a real `save` line (v_save -> save_db) rather than a bare
 *  save_db() call, so the active subject's command state ends on `save` exactly
 *  as the legacy `be/.../save` stream leaves it -- which is what the committed
 *  fixture's per-entity command state records.
 */
static int
l_save(lua_State *L)
{
	const char *path = luaL_optstring(L, 1, NULL);

	if (path != NULL && strcmp(path, libdir) != 0)
		libdir = str_save((char *) path);

	script_cmd(L, sout("save"));
	return 0;
}

/* oly.loc(who)  -- query: the location id containing who (doc §2.4). */
static int
l_loc(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);

	if (!valid_box(who))
		return luaL_error(L, "oly.loc: %d not a valid box", who);

	lua_pushinteger(L, loc(who));
	return 1;
}

/* oly.has_item(who, item)  -- query: does who hold any of item? (doc §2.4) */
static int
l_has_item(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int item = (int) luaL_checkinteger(L, 2);

	if (!valid_box(who))
		return luaL_error(L, "oly.has_item: %d not a valid box", who);

	lua_pushboolean(L, has_item(who, item) > 0);
	return 1;
}

/* oly.id("grok")  -- resolve a registry name to its id (error if unbound). */
static int
l_id(lua_State *L)
{
	const char *name = luaL_checkstring(L, 1);
	int id = reg_lookup(name);

	if (id < 0)
		return luaL_error(L, "oly.id: unknown name '%s'", name);

	lua_pushinteger(L, id);
	return 1;
}

/* oly.name(id)  -- the registry handle bound to id, or nil. */
static int
l_name(lua_State *L)
{
	int id = (int) luaL_checkinteger(L, 1);
	int i;

	for (i = 0; i < reg_count; i++)
		if (reg_ids[i] == id)
		{
			lua_pushstring(L, reg_names[i]);
			return 1;
		}

	lua_pushnil(L);
	return 1;
}


static const luaL_Reg oly_funcs[] = {
	{ "load",		l_load },
	{ "extract_startlocs",	l_extract_startlocs },
	{ "add_player",		l_add_player },
	{ "poof",		l_poof },
	{ "additem",		l_additem },
	{ "guard",		l_guard },
	{ "order",		l_order },
	{ "save",		l_save },
	{ "loc",		l_loc },
	{ "has_item",		l_has_item },
	{ "id",			l_id },
	{ "name",		l_name },
	{ NULL,			NULL }
};

static int
luaopen_oly(lua_State *L)
{
	luaL_newlib(L, oly_funcs);
	return 1;
}


int
main(int argc, char **argv)
{
	lua_State *L;

	if (argc < 2)
	{
		fprintf(stderr, "usage: olyscript-g3 <script.lua>\n");
		return 2;
	}

	call_init_routines();
	setbuf(stderr, NULL);

	L = luaL_newstate();
	if (L == NULL)
	{
		fprintf(stderr, "olyscript-g3: cannot create Lua state\n");
		return 1;
	}

	luaL_openlibs(L);
	luaL_requiref(L, "oly", luaopen_oly, 1);	/* global + require-able */
	lua_pop(L, 1);

	if (luaL_dofile(L, argv[1]) != LUA_OK)
	{
		fprintf(stderr, "olyscript-g3: %s\n", lua_tostring(L, -1));
		lua_close(L);
		return 1;
	}

	lua_close(L);
	return 0;
}
