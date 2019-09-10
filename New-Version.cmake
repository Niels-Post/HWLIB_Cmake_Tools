
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

set(CMAKE_VERBOSE_MAKEFILE ON)

function(get_make_output path makefile target output)
    execute_process(
            COMMAND "make" -f "${makefile}" ${target}
            WORKING_DIRECTORY "${path}"
            OUTPUT_VARIABLE OutVar)
    string(REPLACE "\n" ";" OutVar ${OutVar})
    list(GET OutVar 0 result)
    SET(${output} "${result}" PARENT_SCOPE)
endfunction()

function(get_defines path makefile)
    get_make_output(${path} ${makefile} get_defines output)
    string(REGEX MATCHALL "-D[^ ]*" Defines "${output}")
    string(REGEX REPLACE "(^|;)-D" "\\1" Defines "${Defines}")
    set(defines "${Defines}" PARENT_SCOPE)
endfunction()


function(get_search path makefile)
    get_make_output(${path} ${makefile} get_search output)
    string(REPLACE "./" "" nosingledots "${output}")
    string(PREPEND nosingledots "../")
    string(PREPEND nosingledots "../")
    STRING(REPLACE " " ";" nospaces "${nosingledots}")
    set(search "${nospaces}" PARENT_SCOPE)
endfunction()

function(get_includes path makefile)
    get_make_output(${path} ${makefile} get_includes output)
    string(REPLACE "./" "" nosingledots "${output}")
    string(REPLACE "-I" "" noi "${nosingledots}")
    STRING(REPLACE " " ";" nospaces "${noi}")
    set(includes "${nospaces}" PARENT_SCOPE)
endfunction()

function(get_sources path makefile search)
    string(REPLACE ";" " " search_paths "${search}")
    get_make_output(${path} ${makefile} get_sources output)
    string(REPLACE "./" "" nosingledots "${output}")
    STRING(REPLACE " " ";" nospaces "${nosingledots}")
    set(all_sources "")
    foreach (f ${nospaces})
        if ("${f}" MATCHES [\/])
            list(APPEND all_sources "${f}")
        elseif ("${f}" MATCHES "main.cpp")
            else()
            set(a a-NOTFOUND)
            find_file(a "${f}" PATHS ${search_paths})
            message(${a} ${f})
            file(RELATIVE_PATH relative ${path} ${a})
            list(APPEND all_sources "${relative}")
        endif ()

    endforeach ()
    set(sources "${all_sources}" PARENT_SCOPE)
endfunction()


macro(add_hwlib_bmptk_target name path makefile)
    # Create executable and set default values
    add_executable(${name} ${path}/main.cpp)
    set_property(TARGET ${name} PROPERTY CXX_STANDARD 17)
    set_property(TARGET ${name} PROPERTY C_STANDARD 11)

    # Retrieve Common Flags
    get_make_output(${path} ${makefile} get_common_flags common_flags_output)
    STRING(REPLACE " " ";" common_flags_nospaces "${common_flags_output}")
    set(common_flags "")
    foreach (f ${common_flags_nospaces})
        # Ignore includes, we'll get those later anyway
        if (NOT "${f}" MATCHES -I)
            list(APPEND common_flags "${f}")
        endif ()
    endforeach ()
    string(REPLACE ";" " " common_flags "${common_flags}")

    # Retrieve C Flags
    get_make_output(${path} ${makefile} get_c_flags c_flags)
    get_make_output(${path} ${makefile} get_cpp_flags cpp_flags)
    get_make_output(${path} ${makefile} get_as_flags as_flags)

    set(CMAKE_C_FLAGS "${c_flags} ${common_flags}")
    set(CMAKE_CXX_FLAGS  "${common_flags} ${cpp_flags}")
    set(CMAKE_ASM_FLAGS  "${common_flags} ${as_flags}")

    # Retrieve and set Linker flags
    get_make_output(${path} ${makefile} get_ln_flags ln_flags)


    set(CMAKE_EXE_LINKER_FLAGS "${common_flags} ${ln_flags}")
    set(CMAKE_MODULE_LINKER_FLAGS "${common_flags} ${ln_flags}")

    # Set correct compiler
    get_make_output(${path} ${makefile} get_prefix prefix)
    SET(CMAKE_CXX_COMPILER ${prefix}g++)
    SET(CMAKE_C_COMPILER ${prefix}gcc)
    SET(CMAKE_ASM_COMPILER ${prefix}gcc)



    # Retrieve includes
    get_includes("${path}" "${makefile}")
    list(APPEND search "${includes}")
    list(APPEND CMAKE_INCLUDE_PATH ${search})
    target_include_directories(${name} PRIVATE ${search})
#    target_include_directories(${name} PRIVATE ${WSL_HOMEDIR}/SFML)
    get_sources("${path}" "${makefile}" "${search}")
    message("Sources: " "${sources}")
    target_sources(${name} PUBLIC ${sources})

    get_make_output(${path} ${makefile} get_ln_script ln_script)
    #    get_target_property(_cur_link_deps ${name} LINK_DEPENDS)
    #    string(APPEND _cur_link_deps " ${ln_template}")
    add_custom_target(${name}_linker "make" -f "${makefile}" make_ln_script
            WORKING_DIRECTORY "${path}")
    add_dependencies(${name} ${name}_linker)
    #    set_target_properties(${name} PROPERTIES LINK_DEPENDS "${path}/${ln_script}")

    get_make_output(${path} ${makefile} get_ld_flags ldflags)
    string(REPLACE "${ln_script}" "${path}/${ln_script}" ld_flags "${ldflags}")
    string(APPEND CMAKE_EXE_LINKER_FLAGS ${ld_flags})
endmacro()