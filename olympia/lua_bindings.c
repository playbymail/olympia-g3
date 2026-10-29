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
 *  name/id registry. subitem, know, makeloc and restart followed for the
 *  move-ship fixture (issue #120); add_player's `unformed` list for the
 *  inventory-give fixture and the garrison query for inventory-refused
 *  (issue #127); mob for recruitment-raise's rally target (issue #139);
 *  castle_level for construction-refused's level-six improve (issue #162);
 *  storm for the magic fixtures' bind (issue #170); add_garrison for
 *  governance-refused's pre-existing garrisons (issue #134); mine_depth
 *  for use-shipcraft's mines (issue #190); kill for use-religion's dead
 *  bodies (issue #192); savage for use-beast's keep_savage (issue #194);
 *  palantir for use-art's artifacts (issue #204); potion, orb, ring and
 *  relic for use-items' unique items (issue #218); hide for
 *  phase-daily's barking dogs (issue #233); token, bandit, release,
 *  desert, restock and start for phase-day0's state an earlier turn
 *  leaves (issue #232); clock, auto_quit and pass for the month-end
 *  events gated on the calendar and the map, and loyalty, loot and
 *  collapse (and relic's decay) for the decay an earlier month end
 *  leaves (issue #234); opium for trade-opium's opium market (issue
 *  #252). Everything else in the design
 *  (credit, the wider query set, the declarative format, RNG bindings) is
 *  deferred; a binding is added when a fixture needs it, not speculatively.
 */

#include <limits.h>
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

/*
 *  The subject whose `save` was the last command run, or 0. The db that save
 *  wrote holds that command still in STATE_RUN (v_save runs inside it), which
 *  is what a new process would load -- see l_restart().
 */
static int saved_who = 0;

/*
 *  The characters oly.start() left with an order running. A scripted
 *  command for one would run in its command slot and replace that order,
 *  so script_cmd() refuses one.
 */
static ilist started = NULL;

static void
script_cmd(lua_State *L, char *line)
{
	struct command *c;
	char buf[LEN];

	saved_who = 0;

	if (ilist_lookup(started, immediate) >= 0)
	{
		luaL_error(L, "oly: %d has an order oly.start left running; "
				"start it after its other bindings", immediate);
		return;
	}

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
 *                  email=, name= }
 *      -> { player = <id>, noble = <id>, unformed = { <id>, ... } }
 *
 *  The scripted replacement for guard-pillage steps 3-5 (doc §1.4): mint one
 *  regular faction + starting noble. `id` is the explicit faction box id
 *  (allocated via alloc_box, NO global rnd() draw -- deterministic build
 *  allocation, doc §3.2). The noble is minted by the engine's new_ent() inside
 *  add_new_player(), and its id is captured into the registry under the
 *  author's `noble` handle -- killing the awk id-recovery step. `name` (the
 *  player handle) is bound too when present. `unformed` lists the faction's
 *  unformed noble ids in FORM order, so an order can name a noble the turn
 *  forms (issue #127).
 */
static int
l_add_player(lua_State *L)
{
	int id, noble, i;
	struct entity_player *p;
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

	p = p_player(id);
	lua_newtable(L);
	for (i = 0; i < ilist_len(p->unformed); i++)
	{
		lua_pushinteger(L, p->unformed[i]);
		lua_rawseti(L, -2, i + 1);
	}
	lua_setfield(L, -2, "unformed");

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

/* oly.subitem(who, item, qty)  -- v_sub_item / consume_item. */
static int
l_subitem(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int item = (int) luaL_checkinteger(L, 2);
	int qty = (int) luaL_checkinteger(L, 3);

	be_subject(L, who);
	script_cmd(L, sout("subitem %d %d", item, qty));
	return 0;
}

/* oly.know(who, skill)  -- v_know / learn_skill. */
static int
l_know(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int skill = (int) luaL_checkinteger(L, 2);

	if (kind(skill) != T_skill)
		return luaL_error(L, "oly.know: %d is not a skill", skill);

	be_subject(L, who);
	script_cmd(L, sout("know %d", skill));
	return 0;
}

/*
 *  oly.makeloc(who, "roundship" [, name])  -> <id>
 *
 *  v_makeloc: create a location/ship of the given subkind inside who's
 *  subloc. The verb reports the new box only as text, but set_where() appends
 *  it to the end of that subloc's here_list, so the id is read back from
 *  there -- the scripted replacement for awk'ing lib/ship. `name`, when
 *  given, binds the id in the registry.
 */
static int
l_makeloc(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	const char *sk = luaL_checkstring(L, 2);
	const char *name = luaL_optstring(L, 3, NULL);
	int where, before, n;

	if (!valid_box(who))
		return luaL_error(L, "oly.makeloc: %d not a valid box", who);

	be_subject(L, who);

	where = subloc(who);
	before = ilist_len(rp_loc_info(where)->here_list);
	script_cmd(L, sout("makeloc %s", sk));

	if (ilist_len(rp_loc_info(where)->here_list) != before + 1)
		return luaL_error(L, "oly.makeloc: could not make '%s'", sk);

	n = rp_loc_info(where)->here_list[before];

	if (name != NULL)
		reg_bind(str_save((char *) name), n);

	lua_pushinteger(L, n);
	return 1;
}

/*
 *  oly.mob(where [, name])  -> <id>
 *
 *  Raise a peasant mob at where, as a pillage does (create_peasant_mob):
 *  do_cookie_npc() mints the mob, spends where's mob cookie, and draws its
 *  size from the per-location npc stream, then the mob is queued to guard.
 *  No GM verb makes a mob, so this is the one binding that calls the engine
 *  directly instead of going through script_cmd(). The mob is always named
 *  "Mob", skipping create_peasant_mob's Mob/Crowd draw, so no stream but the
 *  mint is touched. `name`, when given, binds the id in the registry.
 */
static int
l_mob(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	const char *name = luaL_optstring(L, 2, NULL);
	int mob;

	if (!valid_box(where))
		return luaL_error(L, "oly.mob: %d not a valid box", where);

	if (!may_cookie_npc(0, where, item_mob_cookie))
		return luaL_error(L, "oly.mob: no mob may be raised at %d",
				where);

	mob = do_cookie_npc(0, where, item_mob_cookie, where);
	if (mob <= 0)
		return luaL_error(L, "oly.mob: could not raise a mob at %d",
				where);

	set_name(mob, "Mob");
	queue(mob, "guard 1");

	if (name != NULL)
		reg_bind(str_save((char *) name), mob);

	lua_pushinteger(L, mob);
	return 1;
}

/*
 *  oly.storm(where, "rain"|"wind"|"fog", strength [, owner [, name]])  -> <id>
 *
 *  Raise a storm over the province `where`, as a summon spell does
 *  (d_summon_rain and friends): do_cookie_npc() mints the storm and spends
 *  where's storm cookie (it comes back when the storm dissipates), then
 *  new_storm() sets its strength and places it. `owner`, when given and
 *  nonzero, is recorded as the summoner, so it may bind, direct or dissipate
 *  the storm, and its faction sees the province, as after a summon. No GM
 *  verb makes a storm, so this is a path (B) binding, like mob. `name`, when
 *  given, binds the id in the registry.
 */
static int
l_storm(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	const char *sk_s = luaL_checkstring(L, 2);
	int strength = (int) luaL_checkinteger(L, 3);
	int owner = (int) luaL_optinteger(L, 4, 0);
	const char *name = luaL_optstring(L, 5, NULL);
	int sk, cookie, storm;

	if (strcmp(sk_s, "rain") == 0)
	{
		sk = sub_rain;
		cookie = item_rain_cookie;
	}
	else if (strcmp(sk_s, "wind") == 0)
	{
		sk = sub_wind;
		cookie = item_wind_cookie;
	}
	else if (strcmp(sk_s, "fog") == 0)
	{
		sk = sub_fog;
		cookie = item_fog_cookie;
	}
	else
		return luaL_error(L, "oly.storm: '%s' not rain, wind or fog",
				sk_s);

	if (!valid_box(where) || loc_depth(where) != LOC_province)
		return luaL_error(L, "oly.storm: %d not a province", where);

	if (strength < 1 || strength > 32767)
		return luaL_error(L, "oly.storm: strength %d not 1-32767",
				strength);

	if (owner != 0 && kind(owner) != T_char)
		return luaL_error(L, "oly.storm: %d not a character", owner);

	if (!may_cookie_npc(0, where, cookie))
		return luaL_error(L, "oly.storm: no %s storm may be raised at %d",
				sk_s, where);

	storm = do_cookie_npc(owner, where, cookie, where);
	if (storm <= 0)
		return luaL_error(L, "oly.storm: could not raise a storm at %d",
				where);

	new_storm(storm, sk, strength, where);

	if (owner != 0)
		touch_loc_pl(player(owner), where);

	if (name != NULL)
		reg_bind(str_save((char *) name), storm);

	lua_pushinteger(L, storm);
	return 1;
}

/*
 *  oly.castle_level(castle, level)  -> <level>
 *
 *  Set a finished castle's improvement level (0-6), the castle_lev field a
 *  run of improve orders would raise. No GM verb sets it, so this is a path
 *  (B) binding, like mob. Only the level is set: the 5 defense per level
 *  d_improve also adds is left alone.
 */
static int
l_castle_level(lua_State *L)
{
	int castle = (int) luaL_checkinteger(L, 1);
	int level = (int) luaL_checkinteger(L, 2);

	if (!valid_box(castle) || subkind(castle) != sub_castle)
		return luaL_error(L, "oly.castle_level: %d not a castle",
				castle);

	if (level < 0 || level > 6)
		return luaL_error(L, "oly.castle_level: level %d not 0-6",
				level);

	p_subloc(castle)->castle_lev = (schar) level;

	lua_pushinteger(L, castle_level(castle));
	return 1;
}

/*
 *  oly.damage(fort, n)  -> <damage>
 *
 *  Damage a finished building or ship by n (1-99) points, as an earlier
 *  turn's siege would, through add_structure_damage() with can_destroy
 *  FALSE, so the damage stays below 100. No GM verb damages a structure, so
 *  this is a path (B) binding, like castle_level. A fixture's repair needs
 *  damage to repair: makeloc leaves a building undamaged.
 */
static int
l_damage(lua_State *L)
{
	int fort = (int) luaL_checkinteger(L, 1);
	int n = (int) luaL_checkinteger(L, 2);

	if (!valid_box(fort) || loc_depth(fort) != LOC_build)
		return luaL_error(L, "oly.damage: %d not a building or ship",
				fort);

	if (n < 1 || n > 99)
		return luaL_error(L, "oly.damage: %d not 1-99", n);

	add_structure_damage(fort, n, FALSE);

	lua_pushinteger(L, loc_damage(fort));
	return 1;
}

/*
 *  oly.mine_depth(mine, depth)  -> <depth>
 *
 *  Sink a mine to `depth` (1-20, the depth a report shows) and stock it
 *  with that depth's ore, as a finished build does at depth one
 *  (build.c). A mine makeloc creates has no shaft, and the month-end
 *  mine_production() asserts a depth above zero, so a fixture's mine needs
 *  this before the turn. No GM verb sets the depth, so this is a path (B)
 *  binding, like castle_level. The gate crystal a finished build may leave
 *  is not drawn.
 */
static int
l_mine_depth(lua_State *L)
{
	int mine = (int) luaL_checkinteger(L, 1);
	int depth = (int) luaL_checkinteger(L, 2);

	if (!valid_box(mine) || subkind(mine) != sub_mine)
		return luaL_error(L, "oly.mine_depth: %d not a mine", mine);

	if (depth < 1 || depth > 20)
		return luaL_error(L, "oly.mine_depth: depth %d not 1-20",
				depth);

	p_subloc(mine)->shaft_depth = (short) (depth * 3);
	mine_production(mine);

	lua_pushinteger(L, mine_depth(mine));
	return 1;
}

/*
 *  oly.add_garrison(where, castle, item, qty [, name])  -> <id>
 *
 *  Install a garrison of qty item in the province `where`, bound to
 *  `castle` (0 for none, like the garrisons oly.load seeds in cities).
 *  new_province_garrison() mints it, as a garrison order does, but without
 *  v_garrison's checks or its ten soldiers, so a fixture can put a garrison
 *  anywhere before the turn. No GM verb makes a garrison, so this is a path
 *  (B) binding, like mob. `name`, when given, binds the id in the registry.
 */
static int
l_add_garrison(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	int castle = (int) luaL_checkinteger(L, 2);
	int item = (int) luaL_checkinteger(L, 3);
	int qty = (int) luaL_checkinteger(L, 4);
	const char *name = luaL_optstring(L, 5, NULL);
	int garr;

	if (!valid_box(where) || loc_depth(where) != LOC_province)
		return luaL_error(L, "oly.add_garrison: %d not a province",
				where);

	if (garrison_here(where))
		return luaL_error(L, "oly.add_garrison: %d already has a "
				"garrison", where);

	if (castle != 0 && (!valid_box(castle) || subkind(castle) != sub_castle))
		return luaL_error(L, "oly.add_garrison: %d not a castle",
				castle);

	if (!valid_box(item) || kind(item) != T_item)
		return luaL_error(L, "oly.add_garrison: %d not an item", item);

	if (qty < 1)
		return luaL_error(L, "oly.add_garrison: qty %d not positive",
				qty);

	garr = new_province_garrison(where, castle, item, qty);
	if (garr < 0)
		return luaL_error(L, "oly.add_garrison: could not install a "
				"garrison at %d", where);

	if (name != NULL)
		reg_bind(str_save((char *) name), garr);

	lua_pushinteger(L, garr);
	return 1;
}

/*
 *  oly.savage(where, qty [, name])  -> <id>
 *
 *  Mint a band of qty savages at where, bonded as a call to arms leaves one
 *  (call_savage): new_char() makes an independent savage unit with a drum,
 *  as create_savage() does, and set_loyal() bonds it (LOY_summon, 3) so
 *  keep_savage may keep it. qty is given rather than drawn, so no stream
 *  but the mint is touched. No GM verb makes a savage, so this is a path
 *  (B) binding, like mob. `name`, when given, binds the id in the registry.
 */
static int
l_savage(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	int qty = (int) luaL_checkinteger(L, 2);
	const char *name = luaL_optstring(L, 3, NULL);
	int savage;

	if (!valid_box(where) || kind(where) != T_loc)
		return luaL_error(L, "oly.savage: %d not a location", where);

	if (qty < 1)
		return luaL_error(L, "oly.savage: qty %d below 1", qty);

	savage = new_char(sub_ni, item_savage, where, 100, indep_player,
							LOY_npc, 0, NULL);
	if (savage <= 0)
		return luaL_error(L, "oly.savage: could not mint a savage at %d",
				where);

	gen_item(savage, item_drum, 1);
	gen_item(savage, item_savage, qty);
	set_loyal(savage, LOY_summon, 3);

	if (name != NULL)
		reg_bind(str_save((char *) name), savage);

	lua_pushinteger(L, savage);
	return 1;
}

/*
 *  oly.seen(who, num)  -- mark lore sheet num as seen by who's faction.
 *
 *  set_known() on who's player, as queue_lore() does when it delivers a
 *  sheet. The sheet itself is never delivered: deliver_lore is not saved, so
 *  the faction looks as if an earlier turn's report carried it, and the
 *  turn's scan_char_skill_lore() will not send it again. Only `relore`
 *  (queue_lore with anyway) does. No GM verb marks a sheet seen, so this is
 *  a path (B) binding, like mob.
 */
static int
l_seen(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int num = (int) luaL_checkinteger(L, 2);
	int pl;

	if (!valid_box(who) || (pl = player(who)) == 0)
		return luaL_error(L, "oly.seen: %d has no player", who);

	if (!valid_box(num))
		return luaL_error(L, "oly.seen: %d is not a box", num);

	set_known(pl, num);
	return 0;
}

/*
 *  oly.kill(who, holder)  -> <body>
 *
 *  Kill the noble who with the `kill` GM verb (v_kill -> kill_char) and
 *  hand its dead body to holder. kill_char turns the character into a dead
 *  body item, keeping its id, and leaves it in the province; holder takes it
 *  from there, as if it had picked the body up. The verb runs as holder, so
 *  the active subject is never the dead noble. Returns the body's id.
 */
static int
l_kill(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int holder = (int) luaL_checkinteger(L, 2);
	int grave;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.kill: %d not a character", who);

	if (!valid_box(holder) || kind(holder) != T_char || holder == who)
		return luaL_error(L, "oly.kill: %d not another character",
				holder);

	be_subject(L, holder);
	script_cmd(L, sout("kill %d", who));

	if (kind(who) != T_item || subkind(who) != sub_dead_body)
		return luaL_error(L, "oly.kill: %d left no body", who);

	grave = item_unique(who);
	if (!move_item(grave, holder, who, 1))
		return luaL_error(L, "oly.kill: could not give body %d to %d",
				who, holder);

	lua_pushinteger(L, who);
	return 1;
}

/*
 *  oly.sick(who)  -- mark the character who sick.
 *
 *  Sets the sick flag that add_char_damage() sets when a wound makes a
 *  character fall ill, leaving its health as it is. Below full health, a
 *  sick character loses health each month until it recovers or is cured,
 *  and heal works only on one. No GM verb makes a character sick, so this
 *  is a path (B) binding, like mob.
 */
static int
l_sick(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.sick: %d not a character", who);

	p_char(who)->sick = TRUE;
	return 0;
}

/*
 *  oly.hide(who)  -- mark the character who hidden.
 *
 *  Sets the hide_self flag that d_hide sets when use 638 (hide self)
 *  finishes, so who starts the turn hidden, as if an earlier turn hid
 *  it. A hide in the turn takes three days, too late for an early
 *  dog_bark_day. Only a char with no men or stackmates is really
 *  hidden. No GM verb hides a character, so this is a path (B) binding,
 *  like mob.
 */
static int
l_hide(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.hide: %d not a character", who);

	p_magic(who)->hide_self = TRUE;
	return 0;
}

/*
 *  oly.palantir(who [, name])  -> <id>
 *
 *  Give who a palantir, made as d_forge_palantir makes one: a unique item
 *  named Palantir, weight 2, with the palantir use key, created by who in
 *  who's province. No aura or materials are spent. A palantir forged in the
 *  turn gets an id minted in the turn, which no order can name; this one is
 *  minted before it. No GM verb makes a unique item, so this is a path (B)
 *  binding, like mob. `name`, when given, binds the id in the registry.
 */
static int
l_palantir(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	const char *name = luaL_optstring(L, 2, NULL);
	int new;
	struct item_magic *pm;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.palantir: %d not a character", who);

	new = create_unique_item(who, sub_palantir);
	if (new < 0)
		return luaL_error(L, "oly.palantir: could not mint a palantir");

	set_name(new, "Palantir");
	p_item(new)->weight = 2;

	pm = p_item_magic(new);
	pm->use_key = use_palantir;
	pm->creator = who;
	pm->region_created = province(who);

	if (name != NULL)
		reg_bind(str_save((char *) name), new);

	lua_pushinteger(L, new);
	return 1;
}

/*
 *  oly.undead(who [, name])  -> <id>
 *
 *  Summon a demon lord stacked under who, as d_undead_lord does at three
 *  aura: do_cookie_npc() mints it, spends the graveyard's undead cookie, and
 *  draws its corpses from the per-location npc stream, then it is rated 100
 *  and bonded to who (LOY_summon, 5), so renew_undead may keep it. No aura
 *  is spent. One summoned in the turn has an id minted in the turn, which no
 *  order can name. No GM verb makes a demon lord, so this is a path (B)
 *  binding, like mob. `name`, when given, binds the id in the registry.
 */
static int
l_undead(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	const char *name = luaL_optstring(L, 2, NULL);
	int where, undead;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.undead: %d not a character", who);

	where = subloc(who);
	if (!may_cookie_npc(0, where, item_undead_cookie))
		return luaL_error(L, "oly.undead: no demon lord may be "
				"summoned at %d", where);

	undead = do_cookie_npc(who, where, item_undead_cookie, who);
	if (undead <= 0)
		return luaL_error(L, "oly.undead: could not summon a demon "
				"lord at %d", where);

	p_char(undead)->attack = 100;
	p_char(undead)->defense = 100;
	set_loyal(undead, LOY_summon, 5);

	if (name != NULL)
		reg_bind(str_save((char *) name), undead);

	lua_pushinteger(L, undead);
	return 1;
}

/*
 *  oly.potion(who, kind [, value [, name]])  -> <id>
 *
 *  Give who a potion, made as new_potion() makes one: a unique item of
 *  weight 1, created by who in who's province, then given the use key of
 *  kind, as the brew and save spells do. kind is "heal", "death", "slave",
 *  "proj_cast" or "quick_cast". value, when given, is the slave potion's
 *  creator (default who), the proj_cast potion's target location, or the
 *  quick_cast potion's speedup. new_potion() draws the name; this one is
 *  always "Magic potion", so no stream but the mint is touched. A potion
 *  brewed in the turn gets an id minted in the turn, which no order can
 *  name. No GM verb makes a unique item, so this is a path (B) binding,
 *  like mob. `name`, when given, binds the id in the registry.
 */
static int
l_potion(lua_State *L)
{
	static const char *kinds[] = {
		"death", "heal", "slave", "proj_cast", "quick_cast", NULL
	};
	static const int keys[] = {
		use_death_potion, use_heal_potion, use_slave_potion,
		use_proj_cast, use_quick_cast
	};
	int who = (int) luaL_checkinteger(L, 1);
	int key = keys[luaL_checkoption(L, 2, NULL, kinds)];
	int value = (int) luaL_optinteger(L, 3, 0);
	const char *name = luaL_optstring(L, 4, NULL);
	int new;
	struct item_magic *pm;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.potion: %d not a character", who);

	if (key == use_proj_cast && !is_loc_or_ship(value))
		return luaL_error(L, "oly.potion: %d not a location", value);

	if (key == use_slave_potion && value != 0 && kind(value) != T_char)
		return luaL_error(L, "oly.potion: %d not a character", value);

	new = create_unique_item(who, 0);
	if (new < 0)
		return luaL_error(L, "oly.potion: could not mint a potion");

	set_name(new, "Magic potion");
	p_item(new)->weight = 1;

	pm = p_item_magic(new);
	pm->use_key = (schar) key;
	pm->creator = who;
	pm->region_created = province(who);

	if (key == use_slave_potion && value != 0)
		pm->creator = value;
	else if (key == use_proj_cast)
		pm->project_cast = value;
	else if (key == use_quick_cast)
		pm->quick_cast = (short) value;

	if (name != NULL)
		reg_bind(str_save((char *) name), new);

	lua_pushinteger(L, new);
	return 1;
}

/*
 *  oly.orb(who, uses [, name])  -> <id>
 *
 *  Give who an orb, made as new_orb() makes one for quest loot: a unique
 *  item named Orb, weight 1, with the orb use key and lore. new_orb()
 *  draws the number of uses; here it is given, so no stream but the mint
 *  is touched. Only a lair's monster gets one, at an id minted in the
 *  turn. No GM verb makes a unique item, so this is a path (B) binding,
 *  like mob. `name`, when given, binds the id in the registry.
 */
static int
l_orb(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int uses = (int) luaL_checkinteger(L, 2);
	const char *name = luaL_optstring(L, 3, NULL);
	int new;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.orb: %d not a character", who);

	if (uses < 1 || uses > 127)
		return luaL_error(L, "oly.orb: uses %d outside 1..127", uses);

	new = create_unique_item(who, 0);
	if (new < 0)
		return luaL_error(L, "oly.orb: could not mint an orb");

	set_name(new, "Orb");
	p_item(new)->weight = 1;
	p_item_magic(new)->use_key = use_orb;
	p_item_magic(new)->lore = lore_orb;
	p_item_magic(new)->orb_use_count = (schar) uses;

	if (name != NULL)
		reg_bind(str_save((char *) name), new);

	lua_pushinteger(L, new);
	return 1;
}

/*
 *  oly.ring(who, kind [, name])  -> <id>
 *
 *  Give who a golden ring, made as new_suffuse_ring() makes one for a
 *  market: a unique item (sub_suffuse_ring) named Golden ring, weight 1,
 *  with the use key and lore of kind. kind is "barbarian", "savage",
 *  "corpse", "orc" or "skeleton", in new_suffuse_ring()'s order. The
 *  engine draws the kind; here it is given, so no stream but the mint is
 *  touched. A ring restocked in the turn has an id minted in the turn. No
 *  GM verb makes a unique item, so this is a path (B) binding, like mob.
 *  `name`, when given, binds the id in the registry.
 */
static int
l_ring(lua_State *L)
{
	static const char *kinds[] = {
		"barbarian", "savage", "corpse", "orc", "skeleton", NULL
	};
	int who = (int) luaL_checkinteger(L, 1);
	int n = luaL_checkoption(L, 2, NULL, kinds);
	const char *name = luaL_optstring(L, 3, NULL);
	int new;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.ring: %d not a character", who);

	new = create_unique_item(who, sub_suffuse_ring);
	if (new < 0)
		return luaL_error(L, "oly.ring: could not mint a ring");

	set_name(new, "Golden ring");
	p_item(new)->weight = 1;
	p_item_magic(new)->use_key = (schar) (use_barbarian_kill + n);
	p_item_magic(new)->lore = lore_barbarian_kill + n;

	if (name != NULL)
		reg_bind(str_save((char *) name), new);

	lua_pushinteger(L, new);
	return 1;
}

/*
 *  oly.relic(who, id [, decay])
 *
 *  Move the relic id from Nowhere to who, as quest loot gives one to a
 *  lair's monster (move_item from nowhere_loc). Loot also sets the relic
 *  to decay, drawing 9-21 months; with no decay this one does not decay,
 *  and with one it vanishes after decay more month ends, as if loot of
 *  an earlier turn had given it. No GM verb moves a unique item, so this
 *  is a path (B) binding, like mob.
 */
static int
l_relic(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int relic = (int) luaL_checkinteger(L, 2);
	int decay = (int) luaL_optinteger(L, 3, 0);

	if (decay < 0 || decay > SHRT_MAX)
		return luaL_error(L, "oly.relic: decay %d out of range", decay);

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.relic: %d not a character", who);

	if (!valid_box(relic) || kind(relic) != T_item ||
	    subkind(relic) != sub_relic || item_unique(relic) != nowhere_loc)
		return luaL_error(L, "oly.relic: %d not a relic in Nowhere",
				relic);

	move_item(nowhere_loc, who, relic, 1);
	p_item_magic(relic)->relic_decay = (short) decay;
	return 0;
}

/*
 *  oly.loyalty(who, "contract"|"fear"|"summon", rate)
 *
 *  Set who's loyalty, as earlier month ends' loyalty_decay() leaves it:
 *  the three kinds that decay, at rate. A summon at rate 0 is released at
 *  month end; a contract below 50, or a fear unit decaying to 0, may
 *  desert. A unit formed, hired or terrorized in the turn is a fresh
 *  hire, which loyalty_decay() skips, so only a unit of an earlier turn
 *  decays. Errors when who isn't a character. No GM verb sets loyalty,
 *  so this is a path (B) binding, like mob.
 */
static int
l_loyalty(lua_State *L)
{
	static const char *kinds[] = { "contract", "fear", "summon", NULL };
	static const int loy[] = { LOY_contract, LOY_fear, LOY_summon };
	int who = (int) luaL_checkinteger(L, 1);
	int n = luaL_checkoption(L, 2, NULL, kinds);
	int rate = (int) luaL_checkinteger(L, 3);

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.loyalty: %d not a character", who);

	if (rate < 0)
		return luaL_error(L, "oly.loyalty: rate %d below 0", rate);

	set_loyal(who, loy[n], rate);
	return 0;
}

/*
 *  oly.loot(where, n)  -- leave where pillaged by an earlier turn.
 *
 *  Sets the pillage loot of the location where to n, as pillaging does
 *  (each pillage adds 4), but not recent_loot: that flag is not saved,
 *  so a pillage of an earlier turn leaves only the loot. pillage_decay()
 *  lowers it by one at each month end without a pillage. Errors when
 *  where isn't a location or n is out of range. No GM verb pillages, so
 *  this is a path (B) binding, like mob.
 */
static int
l_loot(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	int n = (int) luaL_checkinteger(L, 2);

	if (!valid_box(where) || kind(where) != T_loc)
		return luaL_error(L, "oly.loot: %d not a location", where);

	if (n < 0 || n > SCHAR_MAX)
		return luaL_error(L, "oly.loot: loot %d out of range", n);

	p_subloc(where)->loot = (schar) n;
	return 0;
}

/*
 *  oly.collapse(mine, months)  -- leave an empty mine collapsed.
 *
 *  As building_collapses() collapses a mine (sub_mine_collapsed, mine_delay
 *  8), with months left until collapsed_mine_decay() clears it away, as
 *  earlier month ends leave it. Errors when mine isn't an empty mine or
 *  months is out of range. No GM verb collapses a building, so this is a
 *  path (B) binding, like mob.
 */
static int
l_collapse(lua_State *L)
{
	int mine = (int) luaL_checkinteger(L, 1);
	int months = (int) luaL_checkinteger(L, 2);

	if (!valid_box(mine) || subkind(mine) != sub_mine ||
	    ilist_len(rp_loc_info(mine) ? rp_loc_info(mine)->here_list : NULL) > 0)
		return luaL_error(L, "oly.collapse: %d not an empty mine", mine);

	if (months < 1 || months > 8)
		return luaL_error(L, "oly.collapse: months %d not 1-8", months);

	change_box_subkind(mine, sub_mine_collapsed);
	p_misc(mine)->mine_delay = (schar) months;
	return 0;
}

/*
 *  oly.token(who, kind [, name])  -> <id>
 *
 *  Give who an NPC token, made as create_npc_token() makes one for quest
 *  loot: a unique item (sub_npc_token) controlling one unit of kind's
 *  men, with kind's name and lore. kind is "barbarian", "savage",
 *  "corpse", "orc" or "skeleton", in create_npc_token()'s order. The
 *  engine draws the kind; here it is given, so no stream but the mint is
 *  touched. As from loot, the token has no units yet: check_token_units
 *  adds them at the start of the turn if a player holds it. Only a
 *  lair's monster gets one, at an id minted in the turn. No GM verb
 *  makes a unique item, so this is a path (B) binding, like mob. `name`,
 *  when given, binds the id in the registry.
 */
static int
l_token(lua_State *L)
{
	static const char *kinds[] = {
		"barbarian", "savage", "corpse", "orc", "skeleton", NULL
	};
	static const struct {
		int ni;
		char *name;
		int lore;
	} tok[] = {
		{ item_barbarian, "Crown of the Barbarians",
						lore_barbarian_npc_token },
		{ item_savage, "Horn of the Savages", lore_savage_npc_token },
		{ item_corpse, "Crown of the Undead lord",
						lore_undead_npc_token },
		{ item_orc, "Golden idol of the Orcs", lore_orc_npc_token },
		{ item_skeleton, "Banner of the Skeletons",
						lore_skeleton_npc_token },
	};
	int who = (int) luaL_checkinteger(L, 1);
	int n = luaL_checkoption(L, 2, NULL, kinds);
	const char *name = luaL_optstring(L, 3, NULL);
	int new;
	struct item_magic *pm;

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.token: %d not a character", who);

	new = create_unique_item(who, sub_npc_token);
	if (new < 0)
		return luaL_error(L, "oly.token: could not mint a token");

	set_name(new, tok[n].name);

	pm = p_item_magic(new);
	pm->token_num = 1;
	pm->token_ni = tok[n].ni;
	pm->lore = tok[n].lore;

	if (name != NULL)
		reg_bind(str_save((char *) name), new);

	lua_pushinteger(L, new);
	return 1;
}

/*
 *  oly.token_units(token)  -> <id>
 *
 *  Run check_token_units, as the turn does at its start, so a held NPC
 *  token gets its unit now rather than on day 0, and return the token's
 *  first unit. The unit's id is minted here, before the turn, so orders
 *  and bindings can name it (to put it where it dies in the turn, say).
 *  Errors when token isn't an NPC token or still has no unit. No GM verb
 *  adds a token's units, so this is a path (B) binding, like mob.
 */
static int
l_token_units(lua_State *L)
{
	int token = (int) luaL_checkinteger(L, 1);

	if (!valid_box(token) || subkind(token) != sub_npc_token)
		return luaL_error(L, "oly.token_units: %d not an NPC token",
				token);

	check_token_units();

	if (ilist_len(p_player(token)->units) < 1)
		return luaL_error(L, "oly.token_units: %d has no unit", token);

	lua_pushinteger(L, p_player(token)->units[0]);
	return 1;
}

/*
 *  oly.prisoner(who, target [, swear])  -- who takes target prisoner.
 *
 *  take_prisoner(), as a battle's winner takes one: target is stacked
 *  beneath who as a prisoner and who takes its items. With swear,
 *  target also swears to whoever frees it (swear_on_release), which only
 *  a loaded DB sets: no engine code sets it. Errors when who or target
 *  isn't a character, or they are the same. No GM verb takes a
 *  prisoner, so this is a path (B) binding, like mob.
 */
static int
l_prisoner(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	int target = (int) luaL_checkinteger(L, 2);
	int swear = lua_toboolean(L, 3);

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.prisoner: %d not a character", who);

	if (!valid_box(target) || kind(target) != T_char || target == who)
		return luaL_error(L, "oly.prisoner: %d not another character",
				target);

	take_prisoner(who, target);
	if (swear)
		p_magic(target)->swear_on_release = TRUE;
	return 0;
}

/*
 *  oly.noble_points(pl, n)  -- set player pl's noble points to n.
 *
 *  As a player is left after spending NPs; np_spent is untouched.
 *  Errors when pl isn't a player or n is out of range. No GM verb sets
 *  NPs, so this is a path (B) binding, like mob.
 */
static int
l_noble_points(lua_State *L)
{
	int pl = (int) luaL_checkinteger(L, 1);
	int n = (int) luaL_checkinteger(L, 2);

	if (!valid_box(pl) || kind(pl) != T_player)
		return luaL_error(L, "oly.noble_points: %d not a player", pl);

	if (n < 0 || n > SHRT_MAX)
		return luaL_error(L, "oly.noble_points: %d out of range", n);

	p_player(pl)->noble_points = (short) n;
	return 0;
}

/*
 *  oly.bandit(where, item, qty [, name])  -> <id>
 *
 *  Mint a band of qty item at where, in Hades or Faery, as an ambush
 *  there does (create_hades_bandit, create_faery_bandit): an independent
 *  unit with the region's bandit program and no break point. item is one
 *  the region's ambush draws: spirits, corpses, savages, skeletons or
 *  gorgons in Hades; faeries or elves in Faery. The engine draws the
 *  item and qty, and a Faery band's gold; here they are given and the
 *  band has no gold, so no stream but the mint is touched. An ambush
 *  queues orders for its band, so only one from an earlier turn is idle
 *  when NPC orders are queued. No GM verb makes a bandit, so this is a
 *  path (B) binding, like mob. `name`, when given, binds the id in the
 *  registry.
 */
static int
l_bandit(lua_State *L)
{
	static const int hades[] = {
		item_spirit, item_corpse, item_savage, item_skeleton,
		item_gorgon, 0
	};
	static const int faery[] = { item_faery, item_elf, 0 };
	int where = (int) luaL_checkinteger(L, 1);
	int item = (int) luaL_checkinteger(L, 2);
	int qty = (int) luaL_checkinteger(L, 3);
	const char *name = luaL_optstring(L, 4, NULL);
	const int *items;
	int prog, bandit, i;

	if (!valid_box(where) || kind(where) != T_loc)
		return luaL_error(L, "oly.bandit: %d not a location", where);

	if (in_hades(where))
	{
		prog = PROG_hades_bandit;
		items = hades;
	}
	else if (in_faery(where))
	{
		prog = PROG_faery_bandit;
		items = faery;
	}
	else
		return luaL_error(L, "oly.bandit: %d not in Hades or Faery",
				where);

	for (i = 0; items[i] != 0 && items[i] != item; i++)
		;
	if (items[i] == 0)
		return luaL_error(L, "oly.bandit: no ambush at %d draws %d",
				where, item);

	if (qty < 1)
		return luaL_error(L, "oly.bandit: qty %d below 1", qty);

	bandit = new_char(sub_ni, item, where, -1, indep_player,
							LOY_npc, 0, NULL);
	if (bandit <= 0)
		return luaL_error(L, "oly.bandit: could not mint a bandit "
				"at %d", where);

	p_char(bandit)->break_point = 0;
	p_char(bandit)->npc_prog = (schar) prog;
	gen_item(bandit, item, qty);

	if (name != NULL)
		reg_bind(str_save((char *) name), bandit);

	lua_pushinteger(L, bandit);
	return 1;
}

/*
 *  oly.release(who)  -- let a summoned unit's bond run out.
 *
 *  As loyalty_decay() releases a summon whose loyalty rate is down to
 *  0 at month end: who leaves its stack and becomes an NPC
 *  (LOY_npc), so the next turn's queue_npc_orders() gives it orders.
 *  Errors when who isn't a summoned character. No GM verb releases a
 *  summon, so this is a path (B) binding, like mob.
 */
static int
l_release(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);

	if (!valid_box(who) || kind(who) != T_char ||
	    loyal_kind(who) != LOY_summon)
		return luaL_error(L, "oly.release: %d not a summoned "
				"character", who);

	leave_stack(who);
	set_loyal(who, LOY_npc, 0);
	return 0;
}

/*
 *  oly.desert(who)  -- who deserts to the independent player.
 *
 *  As loyalty_decay() deserts a contract or fear unit at month end
 *  (unit_deserts to indep_player, unsworn): who renounces its lord,
 *  leaves its stack and becomes an unsworn independent, so the next
 *  turn's queue_npc_orders() gives it orders. Errors when who isn't a
 *  character of a player other than the independent one. No GM verb
 *  makes a unit desert, so this is a path (B) binding, like mob.
 */
static int
l_desert(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);

	if (!valid_box(who) || kind(who) != T_char ||
	    player(who) == 0 || player(who) == indep_player)
		return luaL_error(L, "oly.desert: %d not a player's "
				"character", who);

	unit_deserts(who, indep_player, TRUE, LOY_unsworn, 0);
	return 0;
}

/*
 *  oly.restock(where)  -- restock the market of the city where.
 *
 *  loc_trade_sup(), as location_trades() restocks every city at month
 *  end: each good the city produces is offered for sale again, and each
 *  it consumes is wanted again. No pending trade is matched against the
 *  new stock until the next turn's day 1 (match_all_trades), so a buy
 *  that outran the stock is still pending when the turn starts. Errors
 *  when where isn't a city. No GM verb restocks a market, so this is a
 *  path (B) binding, like mob.
 */
static int
l_restock(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);

	if (!valid_box(where) || subkind(where) != sub_city)
		return luaL_error(L, "oly.restock: %d not a city", where);

	loc_trade_sup(where, FALSE);
	return 0;
}

/*
 *  oly.opium(city, level)  -> <level>
 *
 *  Give the city an opium market at addiction level `level` (0-7), as a
 *  month end leaves it: set opium_econ, then opium_market_delta() posts
 *  the CONSUME trade for that level and loc_trade_sup() the BUY that
 *  players sell to. The base world has no opium market, since its only
 *  month end ran before the cities were seeded. With no BUY trade yet
 *  the delta leaves the level alone. No GM verb sets the level, so this
 *  is a path (B) binding, like restock (issue #252).
 */
static int
l_opium(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	int level = (int) luaL_checkinteger(L, 2);

	if (!valid_box(where) || subkind(where) != sub_city)
		return luaL_error(L, "oly.opium: %d not a city", where);

	if (level < 0 || level > 7)
		return luaL_error(L, "oly.opium: level %d not 0-7", level);

	p_subloc(where)->opium_econ = level;
	opium_market_delta(where);
	loc_trade_sup(where, FALSE);

	lua_pushinteger(L, p_subloc(where)->opium_econ);
	return 1;
}

/*
 *  oly.clock(turn)  -- set the turn the game has reached.
 *
 *  Sets sysclock to the start of `turn`, as a game that has run that many
 *  turns saves it (day 0, MONTH_DAYS days per turn since the epoch), so
 *  the next -r runs turn+1. The month-end events gated on the calendar
 *  (special_locs_open/close, add_noble_points) and on a turn count
 *  (dead_body_rot) then fall on that turn. Call it before the bindings
 *  that record the turn, such as add_player. The base world is at turn
 *  0. No GM verb sets the clock, so this is a path (B) binding, like mob.
 */
static int
l_clock(lua_State *L)
{
	int turn = (int) luaL_checkinteger(L, 1);

	if (turn < 0 || turn > SHRT_MAX)
		return luaL_error(L, "oly.clock: turn %d out of range", turn);

	sysclock.turn = (short) turn;
	sysclock.day = 0;
	sysclock.days_since_epoch = turn * MONTH_DAYS;
	return 0;
}

/*
 *  oly.auto_quit(turns)  -- set the game's auto_quit option.
 *
 *  auto_quit_turns, as the auto_quit= line of lib/system sets it: at
 *  month end auto_drop() queues a quit for each player that has sent no
 *  orders for that many turns. 0 turns it off (the default). save_db
 *  writes it back to lib/system. No GM verb sets a game option, so this
 *  is a path (B) binding, like mob.
 */
static int
l_auto_quit(lua_State *L)
{
	int turns = (int) luaL_checkinteger(L, 1);

	if (turns < 0)
		return luaL_error(L, "oly.auto_quit: turns %d below 0", turns);

	auto_quit_turns = turns;
	return 0;
}

/*
 *  oly.pass(where, "uldim"|"summerbridge", flag)
 *
 *  Mark the province where as part of Uldim pass or Summerbridge, as
 *  mapgen does for the map's special glyphs: uldim_flag 1-4 ('^', 'v',
 *  '{', '}') or summer_flag 1-2 (']', '['). Only the flag is set, not
 *  mapgen's name or terrain. The seasonal routes open at the end of month
 *  2 and close at the end of month 6. No GM verb edits the map, and the
 *  shipped maps have neither place, so this is a path (B) binding, like
 *  mob.
 */
static int
l_pass(lua_State *L)
{
	static const char *kinds[] = { "uldim", "summerbridge", NULL };
	int where = (int) luaL_checkinteger(L, 1);
	int n = luaL_checkoption(L, 2, NULL, kinds);
	int flag = (int) luaL_checkinteger(L, 3);

	if (!valid_box(where) || loc_depth(where) != LOC_province)
		return luaL_error(L, "oly.pass: %d not a province", where);

	if (flag < 1 || flag > (n == 0 ? 4 : 2))
		return luaL_error(L, "oly.pass: no %s flag %d", kinds[n], flag);

	if (n == 0)
		p_subloc(where)->uldim_flag = (schar) flag;
	else
		p_subloc(where)->summer_flag = (schar) flag;
	return 0;
}

/*
 *  oly.start(who)  -- start who's next queued order now.
 *
 *  Pops who's top order and runs it through do_command(), as the turn
 *  starts an order it loads, but without the evenings script_cmd() runs
 *  to finish it. A one-day order (buy, guard) is done at once; a longer
 *  one is left running with all its days to go, as an order begun late
 *  in an earlier turn is when the next turn starts. Errors when who
 *  has no queued order or it is not a command. Call it after the other
 *  bindings for who: a scripted command for who runs in who's command
 *  slot and would replace the running order, so script_cmd() refuses
 *  one.
 */
static int
l_start(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	struct command *c;
	char *order;
	char buf[LEN];

	if (!valid_box(who) || kind(who) != T_char)
		return luaL_error(L, "oly.start: %d not a character", who);

	order = top_order(player(who), who);
	if (order == NULL)
		return luaL_error(L, "oly.start: %d has no queued order", who);

	if (immediate == who)
		be_subject(L, gm_player);

	strncpy(buf, order, LEN-1);
	buf[LEN-1] = '\0';
	pop_order(player(who), who);

	c = p_command(who);
	c->who = who;

	if (!oly_parse(c, buf))
		return luaL_error(L, "oly.start: unrecognized order for %d: %s",
				who, buf);

	c->pri = (schar) cmd_tbl[c->cmd].pri;
	c->wait = cmd_tbl[c->cmd].time;
	c->poll = (schar) cmd_tbl[c->cmd].poll;
	c->days_executing = 0;
	c->state = STATE_LOAD;

	do_command(c);

	if (c->state == STATE_RUN)
		ilist_append(&started, who);
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
 *
 *  who may be an unformed noble: its orders are queued under the player
 *  whose unformed list holds it, as the order scanner (eat.c) accepts them,
 *  and run once a form makes the noble.
 */
static int
l_order(lua_State *L)
{
	int who = (int) luaL_checkinteger(L, 1);
	const char *order = luaL_checkstring(L, 2);
	int pl = 0;
	int i;

	if (kind(who) == T_unform)
	{
		loop_player(i)
		{
			if (ilist_lookup(p_player(i)->unformed, who) >= 0)
				pl = i;
		}
		next_player;
	}
	else
		pl = player(who);

	if (pl == 0)
		return luaL_error(L, "oly.order: %d has no player", who);

	queue_order(pl, who, (char *) order);
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
	saved_who = immediate;
	return 0;
}

/*
 *  oly.restart()  -- carry on as a freshly started olympia-g3 process would.
 *
 *  The legacy fixture builds ran each step as its own process against the
 *  saved lib, and three pieces of state differ after the restart:
 *
 *    - the per-turn `mint` stream's counter is never saved, so it starts over;
 *    - every -i run starts as the GM, so its first `be` is recorded on the
 *      GM's box;
 *    - a `save` command writes the db while it is itself still running, so
 *      the subject that saved loads with that command in STATE_RUN (and the
 *      turn then spends that unit's first day finishing it).
 *
 *  A script reproducing such a build byte for byte calls this where the old
 *  flow started a new process, straight after an oly.save() if the old flow
 *  saved there. A scenario authored in Lua from the start never needs it.
 */
static int
l_restart(lua_State *L)
{
	(void) L;

	if (saved_who > 0)
		rp_command(saved_who)->state = STATE_RUN;
	saved_who = 0;

	scenario_reset_mint();
	immediate = gm_player;
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

/*
 *  oly.garrison(where)  -- query: the garrison guarding where, or nil.
 *  load_db() has already seeded the city garrisons (seed_phase_two).
 */
static int
l_garrison(lua_State *L)
{
	int where = (int) luaL_checkinteger(L, 1);
	int garr;

	if (!valid_box(where))
		return luaL_error(L, "oly.garrison: %d not a valid box", where);

	garr = garrison_here(where);
	if (garr == 0)
		lua_pushnil(L);
	else
		lua_pushinteger(L, garr);
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
	{ "subitem",		l_subitem },
	{ "know",		l_know },
	{ "makeloc",		l_makeloc },
	{ "mob",		l_mob },
	{ "storm",		l_storm },
	{ "castle_level",	l_castle_level },
	{ "mine_depth",		l_mine_depth },
	{ "damage",		l_damage },
	{ "add_garrison",	l_add_garrison },
	{ "savage",		l_savage },
	{ "seen",		l_seen },
	{ "kill",		l_kill },
	{ "sick",		l_sick },
	{ "hide",		l_hide },
	{ "palantir",		l_palantir },
	{ "undead",		l_undead },
	{ "potion",		l_potion },
	{ "orb",		l_orb },
	{ "ring",		l_ring },
	{ "relic",		l_relic },
	{ "token",		l_token },
	{ "token_units", l_token_units },
	{ "prisoner",	l_prisoner },
	{ "noble_points", l_noble_points },
	{ "bandit",		l_bandit },
	{ "release",		l_release },
	{ "desert",		l_desert },
	{ "restock",		l_restock },
	{ "opium",		l_opium },
	{ "clock",		l_clock },
	{ "auto_quit",		l_auto_quit },
	{ "pass",		l_pass },
	{ "loyalty",		l_loyalty },
	{ "loot",		l_loot },
	{ "collapse",		l_collapse },
	{ "start",		l_start },
	{ "guard",		l_guard },
	{ "order",		l_order },
	{ "save",		l_save },
	{ "restart",		l_restart },
	{ "loc",		l_loc },
	{ "has_item",		l_has_item },
	{ "garrison",		l_garrison },
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
