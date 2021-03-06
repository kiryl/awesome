# This module is designed to allow the Awesome documentation examples to be
# tested.
#
# It shims enough of the Awesome C API to allow code to be executed without an
# actual X server or running Awesome process. These tests are not genuine
# integration tests, but they are the next best thing.
#
# # As secondary goals, this module also generates images of the test result where
# relevant. Those images are used by the documentation and help the developers
# track user interface regressions and glitches. Finally, it also helps to find
# broken code.
cmake_minimum_required(VERSION 3.0.0)

# Get and update the LUA_PATH so the scripts can be executed without Awesome.
execute_process(COMMAND lua -e print\(package.path\) OUTPUT_VARIABLE "LUA_PATH_")

# Add the main awesome lua libraries.
set(LUA_PATH2_ "\
${CMAKE_SOURCE_DIR}/lib/?.lua;\
${CMAKE_SOURCE_DIR}/lib/?/init.lua;\
${CMAKE_SOURCE_DIR}/lib/?;"
)

# Add the C API shims.
set(LUA_PATH3_ "\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?.lua;\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?/init.lua;\
${CMAKE_SOURCE_DIR}/tests/examples/shims/?;"
)

# Done in 3 variables to avoid CMake from implicitly converting into a list.
set(ENV{LUA_PATH} "${LUA_PATH3_}${LUA_PATH2_}${LUA_PATH_}")

# The documentation images directory
set(IMAGE_DIR "${CMAKE_BINARY_DIR}/doc/images")
file(MAKE_DIRECTORY "${IMAGE_DIR}")

# Escape potentially multiline strings to be part of the API doc.
#  * add "--" in front of each lines
#  * add a custom prefix in front of each lines
#  * drop empty lines
#  * convert " " lines into empty lines
#  * drop lines ending with "--DOC_SOMETHING", they are handled elsewhere
function(escape_string variable content escaped_content line_prefix)
    # If DOC_HIDE_ALL is present, do nothing
    if(variable MATCHES "--DOC_HIDE_ALL")
        return()
    endif()

    string(REGEX REPLACE "\n" ";" var_lines "${variable}")

    set(tmp_output ${content})
    foreach (LINE ${var_lines})
        if(NOT LINE MATCHES "^.+--DOC_[A-Z]+$")
            set(tmp_output ${tmp_output}\n--${line_prefix}${LINE})
        endif()
    endforeach()

    set(${escaped_content} ${tmp_output} PARENT_SCOPE)
endfunction()

# Extract lines with the --DOC_HEADER marker
function(extract_header variable pre_output post_output)
    string(REGEX REPLACE "\n" ";" var_lines "${variable}")

    set(IS_POST 0)

    foreach (LINE ${var_lines})
        # This function doesn't escape the lines, so make sure they are
        # already comments.
        if(LINE MATCHES "^--.*--DOC_HEADER")
            # Remove the header tag
            string(REGEX REPLACE "[ ]*--DOC_HEADER" "" LINE "${LINE}")

            # ldoc is picky about what happen after the first --@, so split
            # the output between all that come before and all that come after.
            if (NOT IS_POST AND LINE MATCHES "^--[ ]*@")
                set(IS_POST 1)
            endif()

            if (IS_POST)
                set(tmp_post_output ${tmp_post_output}\n${line_prefix}${LINE})
            else()
                set(tmp_pre_output ${tmp_pre_output}\n${line_prefix}${LINE})
            endif()
        endif()
    endforeach()

    set(${post_output} "${tmp_post_output}\n--" PARENT_SCOPE)
    set(${pre_output} "${tmp_pre_output}\n--" PARENT_SCOPE)
endfunction()

# Read a code file and convert it to ldoc usage example.
#  * add "--" in front of each lines
#  * drop empty lines
#  * convert " " lines into empty lines
#  * drop lines ending with "--DOC_HIDE"
function(escape_code path escaped_content pre_header post_header)
    file(READ ${path} path)

    escape_string("${path}\n" "" escaped_code "")

    extract_header("${path}" example_pre_header example_post_header)

    set(${escaped_content} ${escaped_code} PARENT_SCOPE)
    set(${pre_header} ${example_pre_header} PARENT_SCOPE)
    set(${post_header} ${example_post_header} PARENT_SCOPE)
endfunction()

# Only gears.debug.print_warning are allowed on stderr, everything else will
# trigger a build failure to catch regressions and problem early.
function(check_for_problems stderr result)

    # If there is nothing to check, return
    if (TEST_ERROR STREQUAL "")
        set(${result} 0 PARENT_SCOPE)
        return()
    endif()

    string(REGEX REPLACE "\n" ";" error_lines "${stderr}")

    foreach (LINE ${error_lines})

        # gears.debug.print_warning lines look like:
        # yyyy-mm-dd hh:mm:ss W: message content
        if (NOT ${LINE} MATCHES "^[0-9 :-]+ W:")
            set(${result} 1 PARENT_SCOPE)
            return()
        endif()

    endforeach()

    set(${result} 0 PARENT_SCOPE)
endfunction()

# Execute a lua file.
function(run_test test_path namespace template escaped_content)

    # A template is required to know how to handle the output.
    if (template STREQUAL " ")
        message(FATAL_ERROR "No template found for " ${test_path} ", bye")
    endif()

    # Get the file name without the extension
    get_filename_component(${test_path} TEST_FILE_NAME NAME)
    set(IMAGE_PATH "${IMAGE_DIR}/AUTOGEN${namespace}_${TEST_FILE_NAME}")

    # Execute the script, leave the image extension decision to the test
    # SVG is preferred, but PNG is better suited for some tests, like bitmap
    # patterns.
    execute_process(
        COMMAND lua ${template} ${test_path} ${IMAGE_PATH} ${SOURCE_DIR}/.luacov
        OUTPUT_VARIABLE TEST_OUTPUT
        ERROR_VARIABLE  TEST_ERROR
    )

    # If there is something on stderr, exit
    check_for_problems("${TEST_ERROR}" problems_found)
    if (${problems_found})
        message("${TEST_OUTPUT}")
        message("${TEST_ERROR}")
        message(FATAL_ERROR ${test_path} " A test failed, bye")
    endif()

    # Read the code and turn it into an usage example.
    escape_code(${test_path} TEST_CODE TEST_PRE_HEADER TEST_POST_HEADER)

    # Build the documentation.
    set(TEST_DOC_CONTENT "${TEST_PRE_HEADER}")

    # If the image has been created, then add it.
    if(EXISTS "${IMAGE_PATH}.svg")
        escape_string(
            "![Usage example](../images/AUTOGEN${namespace}_${TEST_FILE_NAME}.svg)\n"
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
        )
    elseif(EXISTS "${IMAGE_PATH}.png")
        escape_string(
            "![Usage example](../images/AUTOGEN${namespace}_${TEST_FILE_NAME}.png)\n"
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
        )
    endif()

    # If there is an output, assume it is relevant and add it to the
    # documentation under the image.
    if(NOT ${TEST_OUTPUT} STREQUAL "")
        set(TEST_DOC_CONTENT
            "${TEST_DOC_CONTENT}\n--\n--**Usage example output**:\n--"
        )

        # Markdown require an empty line before and after + 4 spaces.
        escape_string(
            "\n${TEST_OUTPUT}"
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT "    "
        )
        set(TEST_DOC_CONTENT "${TEST_DOC_CONTENT}\n--")
    endif()

    # If there is some @* content, append it.
    set(TEST_DOC_CONTENT "${TEST_DOC_CONTENT}${TEST_POST_HEADER}")

    # Only add it if there is something to display.
    if(NOT ${TEST_CODE} STREQUAL "\n--")
        escape_string(
            " @usage"
            "${TEST_DOC_CONTENT}" TEST_DOC_CONTENT ""
        )
        set(TEST_DOC_CONTENT "${TEST_DOC_CONTENT}${TEST_CODE}")
    endif()

    # Export the outout to the parent scope
    set(${escaped_content} "${TEST_DOC_CONTENT}" PARENT_SCOPE)

endfunction()

# Recursive helper function to avoid adding CMakeLists.txt and add_subdirectory
# in every sub-directories.
function(digg path namespace template)

    # Check if there is a template for this directory, else use the
    # last known one.
    if(EXISTS ${path}/template.lua)
        message(STATUS "Testing code based on ${namespace}")
        set(template ${path}/template.lua)
    endif()

    # Get the directory content
    file(GLOB ex_files RELATIVE "${path}"
        "${path}/*")

    foreach(ex_file_name ${ex_files})
        if(IS_DIRECTORY ${path}/${ex_file_name}
            AND (NOT ${ex_file_name} STREQUAL "shims"))

            digg("${path}/${ex_file_name}" "${namespace}_${ex_file_name}" ${template})

        elseif(${ex_file_name} MATCHES ".lua"
            AND NOT ${ex_file_name} MATCHES "template.lua")

            # Get the file name without the extension
            string(REGEX REPLACE "\\.lua" "" TEST_FILE_NAME ${ex_file_name})

            run_test("${path}/${ex_file_name}" "${namespace}" ${template} ESCAPED_CODE_EXAMPLE)

            # Set the test name
            set(TEST_NAME DOC${namespace}_${TEST_FILE_NAME}_EXAMPLE)

            # Anything called @DOC_`namespace`_EXAMPLE@
            # in the Lua or C sources will be replaced by the content if that
            # variable during the pre-processing
            set(ENV{${TEST_NAME}} "${ESCAPED_CODE_EXAMPLE}" CACHE INTERNAL FORCE)

            # Update the test list
            set(ENV{EXAMPLE_LIST} "$ENV{EXAMPLE_LIST};${TEST_NAME}")

        endif()
    endforeach()
endfunction()

# Start at the top level then recursively explore the sub-directories to locate
# the test. In parallel, build a namespace for the global variables. Those
# variables will be inserted into the lua source code itself once the examples
# are validated.
digg("${SOURCE_DIR}/tests/examples" "" " ")

# This is ugly, but CMake variable scope system totally ignore 50 years of
# computer science evolution and only support function local variables.
# PARENT_SCOPE is useless in recursive methods and the CMake pre-processor
# can't access ENV variables. So the only (insane) way is to set tons of ENV
# variables, keep track of them in yet another one and set them in the global
# scope once in the "top level" CMakeLists section (it cannot be done from
# functions).
foreach(vari $ENV{EXAMPLE_LIST})
    # While at it, replace \" created by CMake by ', &quot; wont work in <code>
    string(REGEX REPLACE "\\\"" "'" ${vari} $ENV{${vari}})
endforeach()

message(STATUS "All test passed!")
