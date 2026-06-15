/*
 * onelua.c -- single-translation-unit build of the Lua 5.4.7 library.
 *
 * Vendored for olyscript-g3 (issue #31). This mirrors the upstream
 * src/onelua.c convention but is pinned to MAKE_LIB: it builds ONLY the Lua
 * core + standard library (no standalone interpreter `lua.c` and no compiler
 * `luac.c`, which were dropped from this vendored copy). olyscript-g3 supplies
 * its own main() in olympia/lua_bindings.c.
 *
 * Compiled as its own static library target (lua_vendored) that does NOT take
 * the engine's -Werror modernization ladder -- see CMakeLists.txt and
 * BUILD_HISTORY.md's warning policy.
 */

#define MAKE_LIB

/* Platform features are selected via -DLUA_USE_POSIX on the lua_vendored
 * target (see CMakeLists.txt); luaconf.h reads it. */

/* core -- used by all */
#include "lzio.c"
#include "lctype.c"
#include "lopcodes.c"
#include "lmem.c"
#include "lundump.c"
#include "ldump.c"
#include "lstate.c"
#include "lgc.c"
#include "llex.c"
#include "lcode.c"
#include "lparser.c"
#include "ldebug.c"
#include "lfunc.c"
#include "lobject.c"
#include "ltm.c"
#include "lstring.c"
#include "ltable.c"
#include "ldo.c"
#include "lvm.c"
#include "lapi.c"

/* auxiliary library -- used by all */
#include "lauxlib.c"

/* standard library */
#include "lbaselib.c"
#include "lcorolib.c"
#include "ldblib.c"
#include "liolib.c"
#include "lmathlib.c"
#include "loadlib.c"
#include "loslib.c"
#include "lstrlib.c"
#include "ltablib.c"
#include "lutf8lib.c"
#include "linit.c"
