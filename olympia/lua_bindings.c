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
 *  bodies (issue #192); savage for use-beast's keep_savage (issue #194).
 *  Everything else in the design (credit, the
 *  wider query set, the declarative format, RNG bindings) is deferred; a
 *  binding is added when a fixture needs it, not speculatively.
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

/*
 *  The subject whose `save` was the last command run, or 0. The db that save
 *  wrote holds that command still in STATE_RUN (v_save runs inside it), which
 *  is what a new process would load -- see l_restart().
 */
static int saved_who = 0;

static void
script_cmd(lua_State *L, char *line)
{
	struct command *c;
	char buf[LEN];

	saved_who = 0;

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
	{ "add_garrison",	l_add_garrison },
	{ "savage",		l_savage },
	{ "seen",		l_seen },
	{ "kill",		l_kill },
	{ "sick",		l_sick },
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
