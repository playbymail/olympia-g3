/*
 *  scenario.h -- host hooks for olyscript-g3 (issue #31).
 *
 *  Declarations for the thin reuse wrappers the Lua binding layer
 *  (lua_bindings.c) calls into. These wrap STATIC engine internals (e.g.
 *  add.c's add_new_player()) that have no other public entry point, so the
 *  wrapper bodies live in the engine .c files they belong to, compiled ONLY
 *  when OLYSCRIPT_HOST is defined (the olyscript-g3 target). For the three
 *  shipping targets OLYSCRIPT_HOST is never set, so those files are
 *  byte-identical. See CMakeLists.txt and doc/scripting-tool.md.
 */

#ifndef OLYMPIA_SCENARIO_H
#define OLYMPIA_SCENARIO_H

/*
 *  Mint one regular faction + starting noble exactly as the -a add-player
 *  pass does (alloc_box(pl) + add_new_player()), but driven from explicit
 *  arguments instead of an act/<pl>/Join-g3 file. The faction box `pl` is an
 *  explicit, caller-chosen id (alloc_box, no global rnd() draw); the noble is
 *  minted by the engine's new_ent() and its id is RETURNED so the caller can
 *  bind it in the symbolic-name registry -- removing the awk id-recovery step
 *  (doc/scripting-tool.md §1.4, §2.1). Returns the noble id, or <=0 on
 *  failure.
 */
extern int scenario_add_player(int pl, char *faction, char *character,
			       char *start_city, char *full_name, char *email);

/*
 *  Sort entity `who`'s item list ascending-by-id, exactly as the -a pass's
 *  report generation does in place (report.c). The host calls this on each new
 *  faction + noble so the saved item order matches the legacy authoring flow.
 */
extern void scenario_sort_items(int who);

#endif /* OLYMPIA_SCENARIO_H */
