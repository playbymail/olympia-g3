cmake_minimum_required(VERSION 4.1)
project(olympia-g3 C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# =============================================================================
# Compiler-flag conventions (read before "tidying up" this file)
# =============================================================================
# The 32->64-bit modernization is in progress; classes triaged to ZERO and
# locked as errors live in olympia_compile_flags() below. See CLAUDE.md
# "Modernization status" for the per-phase history and what remains.
#
# 1. Enforced classes are written as an explicit pair, one class per line:
#        -Wfoo -Werror=foo
#    The bare -Wfoo is technically redundant (-Werror=foo already enables it),
#    but the pair is deliberate: it records that the class was driven to zero
#    and locked. Do NOT collapse these to bare -Werror=foo -- the redundancy is
#    a record of completed work, not clutter.
#
# 2. -Wno-foo suppressions are legacy idioms this codebase still relies on and
#    that are NOT being chased down yet (a later phase will turn each into an
#    enforced pair, then drop the matching -Wno- line).
#
# Both sets, plus optional sanitizers, are applied identically to every target
# via olympia_compile_flags() / olympia_enable_sanitizers(). There is one flag
# set for the whole project -- keep it that way. Optimization/debug (-O/-g) is
# owned by CMAKE_BUILD_TYPE / the presets, NOT this file.
# =============================================================================

option(OLYMPIA_SANITIZE "Enable sanitizer instrumentation" OFF)
set(OLYMPIA_SANITIZERS "address,undefined" CACHE STRING "Comma-separated sanitizers, e.g. address,undefined")

# All shared engine warning flags, applied identically to every target.
function(olympia_compile_flags tgt)
    target_compile_options(${tgt} PRIVATE
        # --- Suppressions: legacy idioms left as-is (each becomes an enforced
        #     pair in a later phase, then this line is dropped) ---
        -Wno-comment
        -Wno-compare-distinct-pointer-types
        -Wno-dangling-else
        -Wno-deprecated-declarations
        -Wno-extra-tokens
        # -Wno-format / -Wno-format-security / -Wno-format-nonliteral retired:
        # the whole format class is now enforced below (Phase 9 / issue #7 for
        # -Wformat; issue #20 wrapped the handful of out(who, sout(...)) sites
        # so the non-literal subclass enforces too).
        -Wno-incompatible-library-redeclaration
        -Wno-logical-not-parentheses
        -Wno-macro-redefined
        -Wno-multichar
        -Wno-non-literal-null-conversion
        -Wno-parentheses
        # return-type / return-mismatch are now enforced below (Phase 8 /
        # issue #16) — the fall-off-the-end functions were void-converted or
        # given terminal returns, so both -Wno- lines are dropped.
        # sizeof-pointer-memaccess is now enforced below (Phase 6 / issue #14) —
        # the MD5 memset(ctx, sizeof(ctx)) bug is fixed, so the -Wno- is dropped.
        -Wno-tautological-constant-out-of-range-compare

        # --- Modernization classes triaged to 0 and locked (CLAUDE.md) ---
        # Phase 1 - pointer-cast errors
        -Wint-to-pointer-cast -Werror=int-to-pointer-cast
        -Wpointer-to-int-cast -Werror=pointer-to-int-cast
        # Phase 2 - incompatible pointer types
        -Wincompatible-pointer-types -Werror=incompatible-pointer-types
        # Phase 3 - integer conversions
        -Wint-conversion -Werror=int-conversion
        # Phase 4 - prototypes & declarations
        -Wmissing-prototypes -Werror=missing-prototypes
        -Wstrict-prototypes -Werror=strict-prototypes
        -Wimplicit-function-declaration -Werror=implicit-function-declaration
        # Phase 5 - missing-declarations (lockdown gate before the width phases)
        # A function with no prior declaration is treated as extern int foo(); if
        # it really returns a pointer the caller reads 4 of 8 bytes on LP64. 0
        # hits on clang (Phase 4's prototype work already covered it); the flag is
        # a cross-compiler guard (distinct class on GCC).
        -Wmissing-declarations -Werror=missing-declarations
        # Phase 6 (#14) - 64-bit width hazards, portable half
        # A sizeof(ptr) where sizeof(*ptr) is meant grows 4->8 bytes on LP64
        # (a real corruption risk). The MD5 memset(ctx, sizeof(ctx)) bug is
        # fixed; the class measures 0.
        -Wsizeof-pointer-memaccess -Werror=sizeof-pointer-memaccess
        # Phase 7 (#15) - signed/unsigned implicit conversions. Arch-independent
        # (it bites the same on ILP32 and LP64), but a large class — qsort nmemb
        # counts, the loop_known macro, the MD5 RNG mixes. Portable (GCC + Clang),
        # so it stays in this section, NOT the Clang-only block below.
        -Wsign-conversion -Werror=sign-conversion
        # Phase 8 (#16) - return-type. A non-void function that falls off the
        # end leaves the caller reading a garbage register — 8 bytes on LP64
        # (the class behind G2's fact/100 "st -32" flicker). Portable (GCC +
        # Clang), needed everywhere because it only warns by default, so it
        # stays in this section; the fall-off functions were void-converted or
        # given terminal returns, so the class is 0. The companion bare-`return;`
        # class (-Wreturn-mismatch) is Clang-guarded below — GCC enforces it
        # without the flag, and unconditionally passing it breaks GCC <=13 (#26).
        -Wreturn-type -Werror=return-type
        # Phase 9 (#7) - format-string / vararg checking. -Wno-format had
        # suppressed the whole class engine-wide even though the printf-like
        # wrappers (out/wout/wiout/sout/html, and now queue) carry
        # __attribute__((format)). The worst subclass,
        # -Wformat-insufficient-args (a bare %s with no data arg), deref's a
        # garbage pointer — 8 bytes on LP64. Portable (GCC + Clang), so it
        # stays in this section, NOT the Clang-only block below; the class is
        # 0. -Wformat re-enables -Wformat-security/-nonliteral; issue #20
        # wrapped the deferred non-literal sites so the full class now enforces
        # with no sub-suppression.
        -Wformat -Werror=format
        # -Wformat re-enables -Wformat-zero-length, a GCC sub-warning (Clang
        # does not error on it) that flags the engine's intentional empty-format
        # blank-line idiom -- wout(who, "") / out(who, "") -- at ~140 sites
        # across 25 files. It is not a vararg/type hazard (the Phase 9 target),
        # just a legacy idiom we are not chasing, so suppress it AFTER -Wformat.
        # Portable spelling (both compilers recognize it; no-op on Clang).
        -Wno-format-zero-length
    )

    # Phase 6 (#14) - 64-bit width hazards, Clang-only half.
    # -Wshorten-64-to-32 is a Clang-only diagnostic spelling (GCC folds it into
    # -Wconversion, which is not enabled here); it MUST sit behind this guard or
    # GCC builds break. It isolates the long/size_t/ssize_t-into-int/short
    # truncations that diverge between ILP32 and LP64; the class measures 0.
    #
    # Phase 10 (#17) - implicit-int-conversion is likewise Clang-only (GCC folds
    # it into the broader -Wconversion, which is not enabled here), so it shares
    # this guard with -Wshorten-64-to-32. This is a code-quality / tech-debt
    # class (int->short/char narrowing into narrow entity-struct fields), NOT a
    # 64-bit hazard: arch-independent, identical on ILP32 and LP64. Driven to
    # zero with explicit (short)/(schar)/(char) casts (the on-negation sub-form
    # too); representation-preserving, so golden output is byte-identical. This
    # is the LAST warning phase of the ladder.
    #
    # Phase 8 (#26) - return-mismatch is also Clang-only here. Clang splits bare
    # `return;` in a non-void function out of -Wreturn-type as its own class; GCC
    # enforces it regardless (default permerror on >=14, folded into -Wreturn-type
    # on <=13). The option did not exist before GCC 14 and GCC treats an unknown
    # positive -W* as a fatal error, so passing it unconditionally breaks GCC <=13.
    # Guarding the Clang-only spelling loses no coverage; the class measures 0.
    if (CMAKE_C_COMPILER_ID MATCHES "Clang")
        target_compile_options(${tgt} PRIVATE
            -Wshorten-64-to-32 -Werror=shorten-64-to-32
            -Wimplicit-int-conversion -Werror=implicit-int-conversion
            -Wreturn-mismatch -Werror=return-mismatch
        )
    endif()

    # GCC-only half. -Wformat-overflow is a GCC fortify-style heuristic (no Clang
    # equivalent) that -Wformat pulls in; it flags the legacy fixed-buffer sprintf
    # idiom (sprintf into char[LEN] with %s of an unprovable length, e.g. the
    # main.c html/.htaccess path builders). These are not 64-bit hazards and the
    # paths are short in practice; converting the codebase's sprintf sites to
    # snprintf is a separate cleanup track, not this one. Suppress GCC-only --
    # the spelling is unknown to Clang, so it must sit behind this guard (mirror
    # of the Clang-only block above). Placed after -Wformat, which enables it.
    if (CMAKE_C_COMPILER_ID MATCHES "GNU")
        target_compile_options(${tgt} PRIVATE
            -Wno-format-overflow
        )
    endif()
endfunction()

function(olympia_enable_sanitizers tgt)
    if(NOT OLYMPIA_SANITIZE)
        return()
    endif()
    if(NOT OLYMPIA_SANITIZERS)
        message(FATAL_ERROR "OLYMPIA_SANITIZE is ON but OLYMPIA_SANITIZERS is empty")
    endif()

    # Sanitizers are supported on Clang/GCC; MSVC uses different flags.
    if (CMAKE_C_COMPILER_ID MATCHES "Clang|GNU")
        # Compile and Link flags must match!
        target_compile_options(${tgt} PRIVATE
            -fsanitize=${OLYMPIA_SANITIZERS}
            -fno-omit-frame-pointer
            -fno-optimize-sibling-calls
            -fno-sanitize-recover=all
            -fno-common
        )
        target_link_options(${tgt} PRIVATE
            -fsanitize=${OLYMPIA_SANITIZERS}
            -fno-omit-frame-pointer
            -fno-optimize-sibling-calls
            -fno-sanitize-recover=all
            -fno-common
        )
        if (CMAKE_C_COMPILER_ID MATCHES "Clang")
            # -fsanitize-address-use-after-scope is Clang-only
            target_compile_options(${tgt} PRIVATE
                -fsanitize-address-use-after-scope
            )
            target_link_options(${tgt} PRIVATE
                -fsanitize-address-use-after-scope
            )
        endif()
    else()
        message(WARNING "OLYMPIA_SANITIZE is ON but compiler is not Clang/GNU; sanitizers not enabled.")
    endif()
endfunction()

# ------------------------------------------------------------------------------
# 32-bit build support
# ------------------------------------------------------------------------------
# Enable 32-bit builds on 64-bit Linux systems for generating golden test files
# from the original legacy code before 64-bit refactoring.
#
# Usage:
#   mkdir build32 && cd build32
#   cmake -DBUILD_32BIT=ON ..
#   cmake --build .
#
option(BUILD_32BIT "Build 32-bit binaries (requires gcc-multilib on Linux)" OFF)

if (BUILD_32BIT)
    message(STATUS "32-bit build enabled (-g -m32)")
    add_compile_options(-g -m32)
    add_link_options(-g -m32)
endif()

# Platform-specific defines
if (LINUX)
    add_compile_definitions(OLYMPIA_CC_LINUX)
endif ()
if (WIN32)
    add_compile_definitions(OLYMPIA_CC_WINDOWS)
endif ()

# ------------------------------------------------------------------------------
# G3 island
# ------------------------------------------------------------------------------
add_executable(island-g3)
target_sources(island-g3 PRIVATE
    island/island.c lib/rnd.c lib/rng.c
)
target_include_directories(island-g3 PRIVATE island/ lib/)
# Declare the C11 requirement at the target level (the project-level
# CMAKE_C_STANDARD above stays as the default for any future targets).
target_compile_features(island-g3 PRIVATE c_std_11)
olympia_compile_flags(island-g3)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(island-g3)

# ------------------------------------------------------------------------------
# G3 genesis -- generate a fresh mapgen input set (doc/genesis.md)
# ------------------------------------------------------------------------------
# A FOURTH-family tool, upstream of mapgen-g3: it creates the Map/Regions/Land/
# Cities/randseed inputs that mapgen consumes. It uses its OWN deterministic PCG
# (genesis/pcg.c) -- NOT the MD5-backed lib/rng.c / rnd.c the engine trio shares,
# which stay byte-locked for the golden gates -- so it links neither rnd.c nor
# rng.c. Output is upstream of both golden gates and does not touch them.
add_executable(genesis-g3)
# lib/map_image.c is the ONLY engine-tree source genesis links (issue #81): a
# self-contained glyph-grid -> 24-bit BMP debug exporter that pulls in nothing
# but stdio/stdint -- no engine headers, no RNG -- so it does NOT compromise the
# minimal-source-set rule above (still no lib/rnd.c / lib/rng.c).
target_sources(genesis-g3 PRIVATE
    genesis/genesis.c genesis/pcg.c lib/map_image.c
)
target_sources(genesis-g3 PRIVATE
    FILE_SET HEADERS
    BASE_DIRS
        genesis
        lib
    FILES
        genesis/pcg.h
        genesis/names.h
        lib/map_image.h
)
target_include_directories(genesis-g3 PRIVATE genesis/ lib/)
target_compile_features(genesis-g3 PRIVATE c_std_11)
olympia_compile_flags(genesis-g3)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(genesis-g3)

# ------------------------------------------------------------------------------
# G3 mapgen
# ------------------------------------------------------------------------------
add_executable(mapgen-g3)
target_sources(mapgen-g3 PRIVATE
    mapgen/mapgen.c mapgen/z.c
    lib/ilist.c lib/roads.c lib/tiles.c
    lib/checked_alloc.c lib/rnd.c lib/rng.c
)
target_sources(mapgen-g3 PRIVATE
    FILE_SET HEADERS
    BASE_DIRS
        mapgen lib
    FILES
        mapgen/z.h
        lib/checked_alloc.h
        lib/rnd.h
        lib/rng.h
        lib/lists.h
)
target_include_directories(mapgen-g3 PRIVATE mapgen/ lib/)
# Declare the C11 requirement at the target level (the project-level
# CMAKE_C_STANDARD above stays as the default for any future targets).
target_compile_features(mapgen-g3 PRIVATE c_std_11)
olympia_compile_flags(mapgen-g3)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(mapgen-g3)

# ------------------------------------------------------------------------------
# G3 olympia (main game engine)
# ------------------------------------------------------------------------------
add_executable(olympia-g3)
target_sources(olympia-g3 PRIVATE
    olympia/add.c olympia/adv.c olympia/alchem.c olympia/art.c
    olympia/basic.c olympia/beast.c olympia/build.c
    olympia/buy.c olympia/c1.c olympia/c2.c olympia/check.c
    olympia/cloud.c olympia/code.c olympia/combat.c
    olympia/day.c olympia/dir.c olympia/display.c olympia/eat.c
    olympia/faery.c olympia/garr.c olympia/gate.c
    olympia/glob.c olympia/gm.c olympia/hades.c
    olympia/immed.c olympia/input.c olympia/io.c
    olympia/loc.c olympia/lore.c olympia/main.c olympia/make.c
    olympia/move.c olympia/necro.c olympia/npc.c
    olympia/order.c olympia/perm.c olympia/produce.c
    olympia/pw.c olympia/quest.c olympia/relig.c
    olympia/report.c olympia/rnd.c olympia/savage.c
    olympia/scry.c olympia/seed.c olympia/sout.c
    olympia/stack.c olympia/stealth.c olympia/storm.c
    olympia/summary.c olympia/swear.c olympia/tunnel.c
    olympia/u.c olympia/use.c olympia/z.c

    lib/accept_ents.c lib/admits.c lib/cstrings.c lib/exit_views.c lib/fights.c lib/flag_ents.c lib/item_ents.c
    lib/ilist.c
    lib/orders.c lib/req_ents.c lib/roads.c lib/skill_ents.c lib/tiles.c lib/trades.c lib/wait_args.c
    lib/checked_alloc.c lib/rng.c
)
target_sources(olympia-g3 PRIVATE
    FILE_SET HEADERS
    BASE_DIRS
        olympia lib
    FILES
        olympia/legacy.h
        lib/checked_alloc.h lib/lists.h lib/rng.h
)
target_include_directories(olympia-g3 PRIVATE olympia/ lib/)
# Declare the C11 requirement at the target level (the project-level
# CMAKE_C_STANDARD above stays as the default for any future targets).
target_compile_features(olympia-g3 PRIVATE c_std_11)
olympia_compile_flags(olympia-g3)

# The engine uses sqrt/ceil/... (hades.c, report.c, ...). Linux/GCC needs the
# math library linked explicitly; macOS folds libm into libSystem but tolerates
# -lm. Only the olympia/ tree pulls math, so mapgen-g3/island-g3 don't need it.
target_link_libraries(olympia-g3 PRIVATE m)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(olympia-g3)

# ------------------------------------------------------------------------------
# G3 olyscript -- scenario-scripting host (issue #31)
# ------------------------------------------------------------------------------
# A FOURTH target (the doc's "separate executable" option, doc/scripting-tool.md
# §4/§5) that embeds Lua to author test scenarios. It reuses every engine object
# olympia-g3 builds (so behavior matches -i exactly) plus a single binding TU,
# and links vendored Lua. NOTHING above this line changes: the three shipping
# targets, their flags, and both golden gates are untouched -- olyscript-g3 is
# never built or run by run/olympia-g3.sh or the manifest checks.
#
# Two build-isolation rules from the design (§5.2), and why:
#   1. Vendored Lua is its OWN static lib that does NOT call
#      olympia_compile_flags(): the -Werror modernization ladder stays OFF Lua's
#      sources (they would not survive sign-conversion / shorten-64-to-32 etc.).
#      Per BUILD_HISTORY.md's warning policy "one flag set for the whole project"
#      is about the engine trio, not a ban on separate third-party tiers --
#      PRIVATE per-target scoping is already the architecture.
#   2. OUR binding TU (lua_bindings.c) DOES take the full ladder + sanitizers --
#      it is engine-adjacent code and should be held to the same bar.

# Vendored Lua 5.4.7 -- single-TU build, deliberately NO olympia_compile_flags().
add_library(lua_vendored STATIC third_party/lua/onelua.c)
target_include_directories(lua_vendored PUBLIC third_party/lua)
target_compile_definitions(lua_vendored PRIVATE LUA_USE_POSIX)
target_compile_features(lua_vendored PRIVATE c_std_11)
olympia_enable_sanitizers(lua_vendored)

# The scripting host = every engine source olympia-g3 uses (compiled with
# OLYSCRIPT_HOST, which only drops main.c's main() and enables the scenario.h
# hooks) + the binding TU. The list is duplicated rather than hoisted into a
# shared variable so the olympia-g3 block above is left byte-for-byte alone.
add_executable(olyscript-g3)
target_sources(olyscript-g3 PRIVATE
    olympia/add.c olympia/adv.c olympia/alchem.c olympia/art.c
    olympia/basic.c olympia/beast.c olympia/build.c
    olympia/buy.c olympia/c1.c olympia/c2.c olympia/check.c
    olympia/cloud.c olympia/code.c olympia/combat.c
    olympia/day.c olympia/dir.c olympia/display.c olympia/eat.c
    olympia/faery.c olympia/garr.c olympia/gate.c
    olympia/glob.c olympia/gm.c olympia/hades.c
    olympia/immed.c olympia/input.c olympia/io.c
    olympia/loc.c olympia/lore.c olympia/main.c olympia/make.c
    olympia/move.c olympia/necro.c olympia/npc.c
    olympia/order.c olympia/perm.c olympia/produce.c
    olympia/pw.c olympia/quest.c olympia/relig.c
    olympia/report.c olympia/rnd.c olympia/savage.c
    olympia/scry.c olympia/seed.c olympia/sout.c
    olympia/stack.c olympia/stealth.c olympia/storm.c
    olympia/summary.c olympia/swear.c olympia/tunnel.c
    olympia/u.c olympia/use.c olympia/z.c

    lib/accept_ents.c lib/admits.c lib/cstrings.c lib/exit_views.c lib/fights.c lib/flag_ents.c lib/item_ents.c
    lib/ilist.c
    lib/orders.c lib/req_ents.c lib/roads.c lib/skill_ents.c lib/tiles.c lib/trades.c lib/wait_args.c
    lib/checked_alloc.c lib/rng.c

    olympia/lua_bindings.c
)
target_compile_definitions(olyscript-g3 PRIVATE OLYSCRIPT_HOST)
target_include_directories(olyscript-g3 PRIVATE olympia/ lib/ third_party/lua)
target_compile_features(olyscript-g3 PRIVATE c_std_11)
olympia_compile_flags(olyscript-g3)
olympia_enable_sanitizers(olyscript-g3)
target_link_libraries(olyscript-g3 PRIVATE lua_vendored m)
