#[=======================================================================[.rst:
Papyrus
-------

Compile Papyrus scripts

Usage:

.. code-block:: cmake

  add_papyrus(<target> GAME <game_path>
              [MODE <Skyrim|SkyrimSE|Fallout4>]
              IMPORTS <import> ...
              SOURCES <source> ...
              [FLAGS <flags>]
              [OPTIMIZE] [RELEASE] [FINAL] [VERBOSE] [ANONYMIZE] [SKIP_DEFAULT_IMPORTS])

Using this command will populate the variable ``<target>_OUTPUT`` with the
files that will be generated by the Papyrus compiler.

Example:

.. code-block:: cmake

  add_papyrus("Papyrus"
              GAME $ENV{Skyrim64Path}
              IMPORTS ${CMAKE_CURRENT_SOURCE_DIR}/scripts
                      $ENV{SKSE64Path}/Scripts/Source
              SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/scripts/MOD_Script1.psc
                      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/MOD_Script2.psc
              OPTIMIZE ANONYMIZE)

  add_papyrus("Papyrus"
              GAME $ENV{Fallout4Path}
              MODE Fallout4
              IMPORTS ${CMAKE_CURRENT_SOURCE_DIR}/scripts
              SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/scripts/MOD_Script1.psc
                      ${CMAKE_CURRENT_SOURCE_DIR}/scripts/MOD_Script2.psc
              OPTIMIZE RELEASE FINAL)
#]=======================================================================]

macro(find_pexanon)
	find_program(PEXANON_COMMAND "AFKPexAnon" PATHS "tools/AFKPexAnon")

	if(NOT PEXANON_COMMAND)
		set(PEXANON_DOWNLOAD "${CMAKE_CURRENT_BINARY_DIR}/download/AFKPexAnon-1.1.0-x64.7z")

		file(DOWNLOAD
			"https://github.com/namralkeeg/AFKPexAnon/releases/download/v1.1.0/AFKPexAnon-1.1.0-x64.7z"
			"${PEXANON_DOWNLOAD}"
			EXPECTED_HASH SHA3_224=48721850d462232f2b0e3da91055fbb014b88590a50dac36965c1143
			STATUS PEXANON_STATUS
		)

		list(GET PEXANON_STATUS 0 PEXANON_ERROR_CODE)
		if(PEXANON_ERROR_CODE)
			list(GET PEXANON_STATUS 1 PEXANON_ERROR_MESSAGE)
			message(FATAL_ERROR "${PEXANON_ERROR_MESSAGE}")
		endif()

		file(ARCHIVE_EXTRACT
			INPUT "${PEXANON_DOWNLOAD}"
			DESTINATION "${CMAKE_CURRENT_BINARY_DIR}/tools/AFKPexAnon"
		)

		set(PEXANON_COMMAND "${CMAKE_CURRENT_BINARY_DIR}/tools/AFKPexAnon/AFKPexAnon.exe")
	endif()
endmacro()

function(add_papyrus PAPYRUS_TARGET)
	set(options OPTIMIZE RELEASE FINAL VERBOSE ANONYMIZE SKIP_DEFAULT_IMPORTS)
	set(oneValueArgs GAME MODE FLAGS)
	set(multiValueArgs IMPORTS SOURCES)
	cmake_parse_arguments(PAPYRUS "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if(PAPYRUS_MODE STREQUAL "Fallout4" OR EXISTS "${PAPYRUS_GAME}/Fallout4.exe")
		set(IS_FALLOUT4 TRUE)
	elseif(PAPYRUS_MODE STREQUAL "SkyrimSE" OR EXISTS "${PAPYRUS_GAME}/SkyrimSE.exe")
		set(IS_SKYRIMSE TRUE)
	elseif(PAPYRUS_MODE STREQUAL "Skyrim" OR EXISTS "${PAPYRUS_GAME}/TESV.exe")
		set(IS_SKYRIM TRUE)
	else()
		message(FATAL_ERROR "Invalid add_papyrus mode specified.")
	endif()

	set(QUOTE_LITERAL [=["]=])
	list(APPEND PAPYRUS_IMPORT_DIR "${PAPYRUS_IMPORTS}")
	if(NOT PAPYRUS_SKIP_DEFAULT_IMPORTS)
		if(IS_SKYRIM)
			list(APPEND PAPYRUS_IMPORT_DIR "${PAPYRUS_GAME}/Data/Scripts/Source")
		elseif(IS_SKYRIMSE)
			list(APPEND PAPYRUS_IMPORT_DIR "${PAPYRUS_GAME}/Data/Source/Scripts")
		elseif(IS_FALLOUT4)
			list(APPEND PAPYRUS_IMPORT_DIR
				"${PAPYRUS_GAME}/Data/Scripts/Source/User"
				"${PAPYRUS_GAME}/Data/Scripts/Source/CreationClub"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC06"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC05"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC04"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC03"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC02"
				"${PAPYRUS_GAME}/Data/Scripts/Source/DLC01"
				"${PAPYRUS_GAME}/Data/Scripts/Source/Base"
			)
		endif()
	endif()
	string(APPEND PAPYRUS_IMPORT_ARG ${QUOTE_LITERAL} "${PAPYRUS_IMPORT_DIR}" ${QUOTE_LITERAL})

	set(PAPYRUS_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/Scripts")
	string(APPEND PAPYRUS_OUTPUT_ARG ${QUOTE_LITERAL} "${PAPYRUS_OUTPUT_DIR}" ${QUOTE_LITERAL})

	if(PAPYRUS_FLAGS)
		string(APPEND PAPYRUS_FLAGS_ARG ${QUOTE_LITERAL} "${PAPYRUS_FLAGS}" ${QUOTE_LITERAL})
	else()
		if(IS_SKYRIM OR IS_SKYRIMSE)
			string(APPEND PAPYRUS_FLAGS_ARG ${QUOTE_LITERAL} "TESV_Papyrus_Flags.flg" ${QUOTE_LITERAL})
		elseif(IS_FALLOUT4)
			string(APPEND PAPYRUS_FLAGS_ARG ${QUOTE_LITERAL} "Institute_Papyrus_Flags.flg" ${QUOTE_LITERAL})
		endif()
	endif()

	string(
		APPEND
		PAPYRUS_COMPILER_ARGS
		"-import=${PAPYRUS_IMPORT_ARG} -output=${PAPYRUS_OUTPUT_ARG} -flags=${PAPYRUS_FLAGS_ARG}")

	if(PAPYRUS_FINAL)
		if(IS_FALLOUT4)
			string(APPEND PAPYRUS_COMPILER_ARGS " -optimize -release -final")
		else()
			string(APPEND PAPYRUS_COMPILER_ARGS " -optimize")
		endif()
	elseif(PAPYRUS_RELEASE)
		if(IS_FALLOUT4)
			string(APPEND PAPYRUS_COMPILER_ARGS " -optimize -release")
		else()
			string(APPEND PAPYRUS_COMPILER_ARGS " -optimize")
		endif()
	elseif(PAPYRUS_OPTIMIZE)
		string(APPEND PAPYRUS_COMPILER_ARGS " -optimize")
	endif()

	if(NOT PAPYRUS_VERBOSE)
		string(APPEND PAPYRUS_COMPILER_ARGS " -quiet")
	endif()

	foreach(SOURCE IN ITEMS ${PAPYRUS_SOURCES})
		cmake_path(GET SOURCE STEM LAST_ONLY SOURCE_FILENAME)
		cmake_path(REPLACE_EXTENSION SOURCE_FILENAME LAST_ONLY "pex" OUTPUT_VARIABLE OUTPUT_FILENAME)
		cmake_path(APPEND PAPYRUS_OUTPUT_DIR "${OUTPUT_FILENAME}" OUTPUT_VARIABLE OUTPUT_FILE)
		list(APPEND PAPYRUS_OUTPUT "${OUTPUT_FILE}")

		add_custom_command(
			OUTPUT "${OUTPUT_FILE}"
			COMMAND "${PAPYRUS_GAME}/Papyrus Compiler/PapyrusCompiler.exe"
				"${SOURCE}"
				"${PAPYRUS_COMPILER_ARGS}"
			DEPENDS "${SOURCE}"
		)
	endforeach()

	set(_DUMMY "${CMAKE_CURRENT_BINARY_DIR}/_Papyrus/${PAPYRUS_TARGET}.stamp")
	add_custom_command(
		OUTPUT "${_DUMMY}"
		DEPENDS ${PAPYRUS_OUTPUT}
		COMMAND "${CMAKE_COMMAND}" -E touch "${_DUMMY}"
		VERBATIM
	)

	if(PAPYRUS_ANONYMIZE)
		find_pexanon()

		add_custom_command(
			OUTPUT "${_DUMMY}"
			COMMAND "${PEXANON_COMMAND}" -s "${PAPYRUS_OUTPUT_DIR}"
			COMMAND "${CMAKE_COMMAND}" -E touch "${_DUMMY}"
			VERBATIM
			APPEND
		)
	endif()

	add_custom_target(
		"${PAPYRUS_TARGET}"
		ALL
		DEPENDS "${_DUMMY}"
		SOURCES ${PAPYRUS_SOURCES}
	)

	set("${PAPYRUS_TARGET}_OUTPUT" ${PAPYRUS_OUTPUT} PARENT_SCOPE)

	source_group("Scripts" FILES ${PAPYRUS_SOURCES})

endfunction()
