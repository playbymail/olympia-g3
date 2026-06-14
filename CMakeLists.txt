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
        -Wno-format
        -Wno-format-security
        -Wno-incompatible-library-redeclaration
        -Wno-logical-not-parentheses
        -Wno-macro-redefined
        -Wno-multichar
        -Wno-non-literal-null-conversion
        -Wno-parentheses
        -Wno-return-mismatch
        -Wno-return-type
        -Wno-sizeof-pointer-memaccess
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
    )
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
    mapgen/island.c mapgen/rnd.c
)
target_include_directories(island-g3 PRIVATE island/ mapgen/)
# Declare the C11 requirement at the target level (the project-level
# CMAKE_C_STANDARD above stays as the default for any future targets).
target_compile_features(island-g3 PRIVATE c_std_11)
olympia_compile_flags(island-g3)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(island-g3)

# ------------------------------------------------------------------------------
# G3 mapgen
# ------------------------------------------------------------------------------
add_executable(mapgen-g3)
target_sources(mapgen-g3 PRIVATE
    mapgen/mapgen.c mapgen/rnd.c mapgen/z.c
    lib/ilist.c lib/roads.c lib/tiles.c
)
target_sources(mapgen-g3 PRIVATE
    FILE_SET HEADERS
    BASE_DIRS
        mapgen lib
    FILES
        mapgen/z.h
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
    lib/checked_alloc.c
)
target_sources(olympia-g3 PRIVATE
    FILE_SET HEADERS
    BASE_DIRS
        olympia lib
    FILES
        olympia/legacy.h
        lib/checked_alloc.h lib/lists.h
)
target_include_directories(olympia-g3 PRIVATE olympia/ lib/)
# Declare the C11 requirement at the target level (the project-level
# CMAKE_C_STANDARD above stays as the default for any future targets).
target_compile_features(olympia-g3 PRIVATE c_std_11)
olympia_compile_flags(olympia-g3)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(olympia-g3)
