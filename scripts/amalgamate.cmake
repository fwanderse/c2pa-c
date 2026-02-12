# Concatenate C++ part files into a single compilable c2pa.cpp for distribution.
# Invoked at build time with:
#   cmake -P amalgamate.cmake
#     -DC2PA_SOURCE_DIR=<src dir>
#     -DC2PA_AMALGAM_OUTPUT=<output path>
#     -DC2PA_CPP_PARTS_FILE=<path to file with one part filename per line>
#
# The result is a single file that compiles with only c2pa.hpp (and system headers)
# in the include path. c2pa_internal.hpp is inlined; it is not part of the public API.
#
# All quoted #include "..." lines are stripped from part bodies so that no project
# header or part is ever included twice.
# Only the single #include "c2pa.hpp" and inlined c2pa_internal.hpp at the top are used.

if(NOT C2PA_SOURCE_DIR OR NOT C2PA_AMALGAM_OUTPUT OR NOT C2PA_CPP_PARTS_FILE)
    message(FATAL_ERROR "amalgamate.cmake requires C2PA_SOURCE_DIR, C2PA_AMALGAM_OUTPUT, C2PA_CPP_PARTS_FILE")
endif()
if(NOT EXISTS "${C2PA_CPP_PARTS_FILE}")
    message(FATAL_ERROR "amalgamate.cmake: parts file not found: ${C2PA_CPP_PARTS_FILE}")
endif()
file(STRINGS "${C2PA_CPP_PARTS_FILE}" C2PA_CPP_PARTS)
list(FILTER C2PA_CPP_PARTS INCLUDE REGEX ".+")

set(HEADER
"// Amalgamated c2pa.cpp, generated from sources. Do not edit manually.
// Built by c2pa-c. Single compilable translation unit for distribution.
// Include path: only c2pa.hpp (and system headers) required.

#include \"c2pa.hpp\"

")
file(WRITE "${C2PA_AMALGAM_OUTPUT}" "${HEADER}")

# Inline c2pa_internal.hpp once so downstream need not have it in the path (internal only)
set(C2PA_INTERNAL_HPP "${C2PA_SOURCE_DIR}/c2pa_internal.hpp")
if(NOT EXISTS "${C2PA_INTERNAL_HPP}")
    message(FATAL_ERROR "amalgamate.cmake: c2pa_internal.hpp not found: ${C2PA_INTERNAL_HPP}")
endif()
file(READ "${C2PA_INTERNAL_HPP}" INTERNAL_CONTENT)
file(APPEND "${C2PA_AMALGAM_OUTPUT}" "${INTERNAL_CONTENT}")
file(APPEND "${C2PA_AMALGAM_OUTPUT}" "\n")

# Handle includes manually
foreach(part ${C2PA_CPP_PARTS})
    set(part_path "${C2PA_SOURCE_DIR}/${part}")
    if(NOT EXISTS "${part_path}")
        message(FATAL_ERROR "amalgamate.cmake: part file not found: ${part_path}")
    endif()
    file(STRINGS "${part_path}" LINES)
    set(FILTERED "")
    foreach(LINE IN LISTS LINES)
        string(FIND "${LINE}" "#include \"" IDX)
        if(IDX LESS 0)
            string(APPEND FILTERED "${LINE}\n")
        endif()
    endforeach()
    file(APPEND "${C2PA_AMALGAM_OUTPUT}" "${FILTERED}")
    file(APPEND "${C2PA_AMALGAM_OUTPUT}" "\n")
endforeach()

message(STATUS "Generated amalgamated c2pa.cpp at ${C2PA_AMALGAM_OUTPUT}")
