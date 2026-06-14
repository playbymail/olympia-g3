cmake_minimum_required(VERSION 4.1)
project(olympia-g3 C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

function(legacy_build_flags tgt)
    # Flags to hide legacy code warnings.
    # We'll need to roll some of these back when we're updating the code to run as 64-bit.
    target_compile_options(${tgt} PRIVATE
        -Wno-comment
        -Wno-compare-distinct-pointer-types
        -Wno-dangling-else
        -Wno-deprecated-declarations
        -Wno-extra-tokens
        -Wno-format
        -Wno-format-security
        -Wno-incompatible-library-redeclaration
        -Wno-incompatible-pointer-types
        -Wno-int-conversion
        -Wno-int-to-pointer-cast
        -Wno-logical-not-parentheses
        -Wno-macro-redefined
        -Wno-multichar
        -Wno-non-literal-null-conversion
        -Wno-parentheses
        -Wno-pointer-to-int-cast
        -Wno-return-mismatch
        -Wno-return-type
        -Wno-sizeof-pointer-memaccess
        -Wno-tautological-constant-out-of-range-compare
    )
endfunction()

function(phase_1_build_flags tgt)
    # i/pointer lists triage - only pointer-cast errors.
    target_compile_options(${tgt} PRIVATE
        -Wint-to-pointer-cast -Werror=int-to-pointer-cast
        -Wpointer-to-int-cast -Werror=pointer-to-int-cast
    )
endfunction()

function(phase_2_build_flags tgt)
    # incompatible pointer types
    target_compile_options(${tgt} PRIVATE
        -Wincompatible-pointer-types -Werror=incompatible-pointer-types
    )
endfunction()

function(phase_3_build_flags tgt)
    # integer conversions
    target_compile_options(${tgt} PRIVATE
        -Wint-conversion -Werror=int-conversion
    )
endfunction()

function(phase_4_build_flags tgt)
    # forward declarations; start turning on errors
    target_compile_options(${tgt} PRIVATE
        -Wmissing-prototypes -Werror=missing-prototypes
        -Wstrict-prototypes -Werror=strict-prototypes
        -Wimplicit-function-declaration -Werror=implicit-function-declaration
    )
endfunction()

function(phase_5_build_flags tgt)
    # C11's enabled, sanitizers enabled
    target_compile_options(${tgt} PRIVATE
        -Wmissing-declarations -Werror=missing-declarations
        # string literal to char* is a classic legacy footgun
        #-Wwrite-strings #-Werror=write-strings
        -fno-common
        -fno-omit-frame-pointer
        -fno-optimize-sibling-calls
        -fsanitize=address,undefined
        -fno-sanitize-recover=all
    )
    target_link_options(${tgt} PRIVATE
        -fno-common
        -fno-omit-frame-pointer
        -fno-optimize-sibling-calls
        -fsanitize=address,undefined
        -fno-sanitize-recover=all
    )
endfunction()

option(OLYMPIA_SANITIZE "Enable sanitizer instrumentation" OFF)
set(OLYMPIA_SANITIZERS "" CACHE STRING "Comma-separated sanitizers, e.g. address,undefined"
    address,undefined
)

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

# Engine-specific flags to hide legacy code warnings. We'll need to roll
# some of these back when we're updating the code to run as 64-bit.
set(LEGACY_C_FLAGS
        -Wno-comment
        -Wno-compare-distinct-pointer-types
        -Wno-dangling-else
        -Wno-deprecated-declarations
        -Wno-extra-tokens
        -Wno-format
        -Wno-format-security
        -Wno-incompatible-library-redeclaration
        -Wno-incompatible-pointer-types
        -Wno-int-conversion
        -Wno-int-to-pointer-cast
        -Wno-logical-not-parentheses
        -Wno-macro-redefined
        -Wno-multichar
        -Wno-non-literal-null-conversion
        -Wno-parentheses
        -Wno-pointer-to-int-cast
        -Wno-return-mismatch
        -Wno-return-type
        -Wno-sizeof-pointer-memaccess
        -Wno-tautological-constant-out-of-range-compare
)

# Create a stricter set of compiler flags to catch
set(LEGACY_C_FLAGS_STRICT
        ${LEGACY_C_FLAGS}
)

# Remove suppressions that hide 64-bit hazards
list(REMOVE_ITEM LEGACY_C_FLAGS_STRICT
        -Wno-int-conversion
        -Wno-int-to-pointer-cast
        -Wno-pointer-to-int-cast
        -Wno-implicit-function-declaration
        -Wno-return-mismatch
        -Wno-return-type
)

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
target_compile_options(island-g3 PRIVATE ${LEGACY_C_FLAGS} -Og -g
    # Phase 4 - prototypes & declarations
    -Wmissing-prototypes -Werror=missing-prototypes
    -Wstrict-prototypes -Werror=strict-prototypes
    -Wimplicit-function-declaration -Werror=implicit-function-declaration
)

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
target_compile_options(mapgen-g3 PRIVATE
    ${LEGACY_C_FLAGS} -Og -g
    -Wint-conversion -Werror=int-conversion
    -Wint-to-pointer-cast -Werror=int-to-pointer-cast
    -Wpointer-to-int-cast -Werror=pointer-to-int-cast
    -Wincompatible-pointer-types -Werror=incompatible-pointer-types
    # Phase 4 - prototypes & declarations
    -Wmissing-prototypes -Werror=missing-prototypes
    -Wstrict-prototypes -Werror=strict-prototypes
    -Wimplicit-function-declaration -Werror=implicit-function-declaration
)

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
target_compile_options(olympia-g3 PRIVATE
    ${LEGACY_C_FLAGS} -Og -g
    # Phase 1 - list triage - only pointer-cast errors
    -Wint-to-pointer-cast -Werror=int-to-pointer-cast
    -Wpointer-to-int-cast -Werror=pointer-to-int-cast
    # Phase 2 - incompatible pointer types
    -Wincompatible-pointer-types -Werror=incompatible-pointer-types
    # Phase 4 - prototypes & declarations
    -Wmissing-prototypes -Werror=missing-prototypes
    -Wstrict-prototypes -Werror=strict-prototypes
    -Wimplicit-function-declaration -Werror=implicit-function-declaration
)

# Optional ASan/UBSan via the asan-ubsan preset (OLYMPIA_SANITIZE=ON).
olympia_enable_sanitizers(olympia-g3)
