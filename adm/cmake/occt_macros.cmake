#
macro (OCCT_CHECK_AND_UNSET VARNAME)
  if (DEFINED ${VARNAME})
    unset (${VARNAME} CACHE)
  endif()
endmacro()

macro (OCCT_CHECK_AND_UNSET_GROUP VARNAME)
  OCCT_CHECK_AND_UNSET ("${VARNAME}_DIR")

  OCCT_CHECK_AND_UNSET ("${VARNAME}_INCLUDE_DIR")

  OCCT_CHECK_AND_UNSET ("${VARNAME}_LIBRARY")
  OCCT_CHECK_AND_UNSET ("${VARNAME}_LIBRARY_DIR")

  if (WIN32)
    OCCT_CHECK_AND_UNSET ("${VARNAME}_DLL")
    OCCT_CHECK_AND_UNSET ("${VARNAME}_DLL_DIR")
  endif()
endmacro()

# COMPILER_BITNESS variable
macro (OCCT_MAKE_COMPILER_BITNESS)
  math (EXPR COMPILER_BITNESS "32 + 32*(${CMAKE_SIZEOF_VOID_P}/8)")
endmacro()

# OS_WITH_BIT
macro (OCCT_MAKE_OS_WITH_BITNESS)

  OCCT_MAKE_COMPILER_BITNESS()

  if (WIN32)
    set (OS_WITH_BIT "win${COMPILER_BITNESS}")
  elseif(APPLE)
    set (OS_WITH_BIT "mac${COMPILER_BITNESS}")
  else()
    set (OS_WITH_BIT "lin${COMPILER_BITNESS}")
  endif()
endmacro()

# COMPILER variable
macro (OCCT_MAKE_COMPILER_SHORT_NAME)
  if (MSVC)
    if (MSVC70)
      set (COMPILER vc7)
    elseif (MSVC80)
      set (COMPILER vc8)
    elseif (MSVC90)
      set (COMPILER vc9)
    elseif (MSVC10)
      set (COMPILER vc10)
    elseif (MSVC11)
      set (COMPILER vc11)
    elseif (MSVC12)
      set (COMPILER vc12)
    endif()
  elseif (DEFINED CMAKE_COMPILER_IS_GNUCC)
    set (COMPILER gcc)
  elseif (DEFINED CMAKE_COMPILER_IS_GNUCXX)
    set (COMPILER gxx)
  elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
    set (COMPILER clang)
  elseif ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Intel")
    set (COMPILER icc)
  else()
    set (COMPILER ${CMAKE_GENERATOR})
    string (REGEX REPLACE " " "" COMPILER ${COMPILER})
  endif()
endmacro()

function (SUBDIRECTORY_NAMES MAIN_DIRECTORY RESULT)
  file (GLOB SUB_ITEMS "${MAIN_DIRECTORY}/*")

  foreach (ITEM ${SUB_ITEMS})
    if (IS_DIRECTORY "${ITEM}")
      get_filename_component (ITEM_NAME "${ITEM}" NAME)
      list (APPEND LOCAL_RESULT "${ITEM_NAME}")
    endif()
  endforeach()
  set (${RESULT} ${LOCAL_RESULT} PARENT_SCOPE)
endfunction()

function (FIND_PRODUCT_DIR ROOT_DIR PRODUCT_NAME RESULT)
  OCCT_MAKE_COMPILER_SHORT_NAME()
  OCCT_MAKE_COMPILER_BITNESS()

  string (TOLOWER "${PRODUCT_NAME}" lower_PRODUCT_NAME)

  list (APPEND SEARCH_TEMPLATES "${lower_PRODUCT_NAME}.*${COMPILER}.*${COMPILER_BITNESS}")
  list (APPEND SEARCH_TEMPLATES "${lower_PRODUCT_NAME}.*[0-9.]+.*${COMPILER}.*${COMPILER_BITNESS}")
  list (APPEND SEARCH_TEMPLATES "${lower_PRODUCT_NAME}.*[0-9.]+.*${COMPILER_BITNESS}")
  list (APPEND SEARCH_TEMPLATES "${lower_PRODUCT_NAME}.*[0-9.]+")
  list (APPEND SEARCH_TEMPLATES "${lower_PRODUCT_NAME}")

  SUBDIRECTORY_NAMES ("${ROOT_DIR}" SUBDIR_NAME_LIST)

  foreach (SEARCH_TEMPLATE ${SEARCH_TEMPLATES})
    if (LOCAL_RESULT)
      BREAK()
    endif()

    foreach (SUBDIR_NAME ${SUBDIR_NAME_LIST})
      string (TOLOWER "${SUBDIR_NAME}" lower_SUBDIR_NAME)

      string (REGEX MATCH "${SEARCH_TEMPLATE}" DUMMY_VAR "${lower_SUBDIR_NAME}")
      if (DUMMY_VAR)
        list (APPEND LOCAL_RESULT ${SUBDIR_NAME})
      endif()
    endforeach()
  endforeach()

  if (LOCAL_RESULT)
    list (LENGTH "${LOCAL_RESULT}" LOC_LEN)
    math (EXPR LAST_ELEMENT_INDEX "${LOC_LEN}-1")
    list (GET LOCAL_RESULT ${LAST_ELEMENT_INDEX} DUMMY)
    set (${RESULT} ${DUMMY} PARENT_SCOPE)
  endif()
endfunction()

macro (OCCT_INSTALL_FILE_OR_DIR BEING_INSTALLED_OBJECT DESTINATION_PATH)
  if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/${BEING_INSTALLED_OBJECT}")
    if (IS_DIRECTORY "${BUILD_PATCH_DIR}/${BEING_INSTALLED_OBJECT}")
      # first of all, install original files
      install (DIRECTORY "${CMAKE_SOURCE_DIR}/${BEING_INSTALLED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")

      # secondly, rewrite original files with patched ones
      install (DIRECTORY "${BUILD_PATCH_DIR}/${BEING_INSTALLED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")
    else()
      install (FILES     "${BUILD_PATCH_DIR}/${BEING_INSTALLED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")
    endif()
  else()
    if (IS_DIRECTORY "${CMAKE_SOURCE_DIR}/${BEING_INSTALLED_OBJECT}")
      install (DIRECTORY "${CMAKE_SOURCE_DIR}/${BEING_INSTALLED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")
    else()
      install (FILES     "${CMAKE_SOURCE_DIR}/${BEING_INSTALLED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")
    endif()
  endif()
endmacro()

macro (OCCT_CONFIGURE_AND_INSTALL BEING_CONGIRUGED_FILE FINAL_NAME DESTINATION_PATH)
  if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/${BEING_CONGIRUGED_FILE}")
    configure_file("${BUILD_PATCH_DIR}/${BEING_CONGIRUGED_FILE}" "${FINAL_NAME}" @ONLY)
  else()
    configure_file("${CMAKE_SOURCE_DIR}/${BEING_CONGIRUGED_FILE}" "${FINAL_NAME}" @ONLY)
  endif()

  install(FILES "${OCCT_BINARY_DIR}/${FINAL_NAME}" DESTINATION  "${DESTINATION_PATH}")
endmacro()

macro (COLLECT_AND_INSTALL_OCCT_HEADER_FILES ROOT_OCCT_DIR TEMPLATE_HEADER_PATH ROOT_TARGET_OCCT_DIR OCCT_USED_TOOLKITS)
  set (OCCT_SOURCE_DIRS)

  foreach (OCCT_USED_TOOLKIT ${OCCT_USED_TOOLKITS})
    # append parent folder
    list (APPEND OCCT_SOURCE_DIRS ${OCCT_USED_TOOLKIT})

    # append all required package folders
    set (OCCT_USED_TOOLKIT_DEPS)
    if (EXISTS "${ROOT_OCCT_DIR}/src/${OCCT_USED_TOOLKIT}/PACKAGES")
      file (STRINGS "${ROOT_OCCT_DIR}/src/${OCCT_USED_TOOLKIT}/PACKAGES" OCCT_USED_TOOLKIT_DEPS)
    endif()

    foreach (OCCT_USED_TOOLKIT_DEP ${OCCT_USED_TOOLKIT_DEPS})
      list (APPEND OCCT_SOURCE_DIRS ${OCCT_USED_TOOLKIT_DEP})
    endforeach()
  endforeach()

  foreach (OCCT_SOURCE_DIR ${OCCT_SOURCE_DIRS})
    # get all header files from each src folder 
    file (GLOB OCCT_HEADER_FILES "${ROOT_OCCT_DIR}/src/${OCCT_SOURCE_DIR}/*.[hgl]xx" "${ROOT_OCCT_DIR}/src/${OCCT_SOURCE_DIR}/*.h")

    install (FILES ${OCCT_HEADER_FILES} DESTINATION "${INSTALL_DIR}/inc")

    # create new file including found header
    foreach (OCCT_HEADER_FILE ${OCCT_HEADER_FILES})
      get_filename_component (HEADER_FILE_NAME ${OCCT_HEADER_FILE} NAME)
      configure_file ("${TEMPLATE_HEADER_PATH}" "${ROOT_TARGET_OCCT_DIR}/inc/${HEADER_FILE_NAME}" @ONLY)
    endforeach()
  endforeach()
endmacro()

macro (OCCT_COPY_FILE_OR_DIR BEING_COPIED_OBJECT DESTINATION_PATH)
  # first of all, copy original files
  file (COPY "${CMAKE_SOURCE_DIR}/${BEING_COPIED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")

  if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/${BEING_COPIED_OBJECT}")
    # secondly, rewrite original files with patched ones
    file (COPY "${BUILD_PATCH_DIR}/${BEING_COPIED_OBJECT}" DESTINATION  "${DESTINATION_PATH}")
  endif()
endmacro()

macro (OCCT_CONFIGURE BEING_CONGIRUGED_FILE FINAL_NAME)
  if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/${BEING_CONGIRUGED_FILE}")
    configure_file("${BUILD_PATCH_DIR}/${BEING_CONGIRUGED_FILE}" "${FINAL_NAME}" @ONLY)
  else()
    configure_file("${CMAKE_SOURCE_DIR}/${BEING_CONGIRUGED_FILE}" "${FINAL_NAME}" @ONLY)
  endif()
endmacro()

function (OCCT_IS_PRODUCT_REQUIRED CSF_VAR_NAME USE_PRODUCT)
  set (${USE_PRODUCT} OFF PARENT_SCOPE)

  if (NOT USED_TOOLKITS)
    message(STATUS "Warning: the list of being used toolkits is empty")
  else()
    foreach (USED_TOOLKIT ${USED_TOOLKITS})
      if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/src/${USED_TOOLKIT}/EXTERNLIB")
        file (READ "${BUILD_PATCH_DIR}/src/${USED_TOOLKIT}/EXTERNLIB" FILE_CONTENT)
      elseif (EXISTS "${CMAKE_SOURCE_DIR}/src/${USED_TOOLKIT}/EXTERNLIB")
        file (READ "${CMAKE_SOURCE_DIR}/src/${USED_TOOLKIT}/EXTERNLIB" FILE_CONTENT)
      endif()

      string (REGEX MATCH "${CSF_VAR_NAME}" DOES_FILE_CONTAIN "${FILE_CONTENT}")

      if (DOES_FILE_CONTAIN)
        set (${USE_PRODUCT} ON PARENT_SCOPE)
        break()
      endif()
    endforeach()
  endif()
endfunction()

function (FILE_TO_LIST FILE_NAME FILE_CONTENT)
  set (LOCAL_FILE_CONTENT)
  if (BUILD_PATCH_DIR AND EXISTS "${BUILD_PATCH_DIR}/${FILE_NAME}")
    file (STRINGS "${BUILD_PATCH_DIR}/${FILE_NAME}" LOCAL_FILE_CONTENT)
  elseif (EXISTS "${CMAKE_SOURCE_DIR}/${FILE_NAME}")
    file (STRINGS "${CMAKE_SOURCE_DIR}/${FILE_NAME}" LOCAL_FILE_CONTENT)
  endif()

  set (${FILE_CONTENT} ${LOCAL_FILE_CONTENT} PARENT_SCOPE)
endfunction()

# Function to determine if TOOLKIT is OCCT toolkit
function (IS_OCCT_TOOLKIT TOOLKIT_NAME MODULES IS_TOOLKIT_FOUND)
  set (${IS_TOOLKIT_FOUND} OFF PARENT_SCOPE)
  foreach (MODULE ${${MODULES}})
    set (TOOLKITS ${${MODULE}_TOOLKITS})
    list (FIND TOOLKITS ${TOOLKIT_NAME} FOUND)

    if (NOT ${FOUND} EQUAL -1)
      set (${IS_TOOLKIT_FOUND} ON PARENT_SCOPE)
    endif()
  endforeach(MODULE)
endfunction()

# TOOLKIT_DEPS is defined with dependencies from file src/TOOLKIT_NAME/EXTERNLIB.
# CSF_ variables are ignored
function (OCCT_TOOLKIT_DEP TOOLKIT_NAME TOOLKIT_DEPS)
  FILE_TO_LIST ("src/${TOOLKIT_NAME}/EXTERNLIB" FILE_CONTENT)

  #list (APPEND LOCAL_TOOLKIT_DEPS ${TOOLKIT_NAME})
  set (LOCAL_TOOLKIT_DEPS)
  foreach (FILE_CONTENT_LINE ${FILE_CONTENT})
    string (REGEX MATCH "^TK" TK_FOUND ${FILE_CONTENT_LINE})
    if ("${FILE_CONTENT_LINE}" STREQUAL "DRAWEXE" OR NOT "${TK_FOUND}" STREQUAL "")
      list (APPEND LOCAL_TOOLKIT_DEPS ${FILE_CONTENT_LINE})
    endif()
  endforeach()

  set (${TOOLKIT_DEPS} ${LOCAL_TOOLKIT_DEPS} PARENT_SCOPE)
endfunction()

# TOOLKIT_FULL_DEPS is defined with complete dependencies (all levels)
function (OCCT_TOOLKIT_FULL_DEP TOOLKIT_NAME TOOLKIT_FULL_DEPS)
  # first level dependencies are stored in LOCAL_TOOLKIT_FULL_DEPS
  OCCT_TOOLKIT_DEP (${TOOLKIT_NAME} LOCAL_TOOLKIT_FULL_DEPS)

  list (LENGTH LOCAL_TOOLKIT_FULL_DEPS LIST_LENGTH)
  set (LIST_INDEX 0)
  while (LIST_INDEX LESS LIST_LENGTH)
    list (GET LOCAL_TOOLKIT_FULL_DEPS ${LIST_INDEX} CURRENT_TOOLKIT)
    OCCT_TOOLKIT_DEP (${CURRENT_TOOLKIT} CURRENT_TOOLKIT_DEPS)

    # append toolkits are not contained
    foreach (CURRENT_TOOLKIT_DEP ${CURRENT_TOOLKIT_DEPS})
      set (CURRENT_TOOLKIT_DEP_FOUND OFF)
      foreach (LOCAL_TOOLKIT_FULL_DEP ${LOCAL_TOOLKIT_FULL_DEPS})
        if ("${CURRENT_TOOLKIT_DEP}" STREQUAL "${LOCAL_TOOLKIT_FULL_DEP}")
          set (CURRENT_TOOLKIT_DEP_FOUND ON)
          break()
        endif()
      endforeach()
      if ("${CURRENT_TOOLKIT_DEP_FOUND}" STREQUAL "OFF")
        list (APPEND LOCAL_TOOLKIT_FULL_DEPS ${CURRENT_TOOLKIT_DEP})
      endif()
    endforeach()

    # increment the list index
    MATH(EXPR LIST_INDEX "${LIST_INDEX}+1")

    # calculate new length
    list (LENGTH LOCAL_TOOLKIT_FULL_DEPS LIST_LENGTH)
  endwhile()

  set (${TOOLKIT_FULL_DEPS} ${LOCAL_TOOLKIT_FULL_DEPS} PARENT_SCOPE)
endfunction()

# Function to get list of modules and toolkits from file adm/MODULES.
# Creates list <$MODULE_LIST> to store list of MODULES and
# <NAME_OF_MODULE>_TOOLKITS foreach module to store its toolkits.
function (OCCT_MODULES_AND_TOOLKITS MODULE_LIST)
  FILE_TO_LIST ("adm/MODULES" FILE_CONTENT)

  foreach (CONTENT_LINE ${FILE_CONTENT})
    string (REPLACE " " ";" CONTENT_LINE ${CONTENT_LINE})
    list (GET CONTENT_LINE 0 MODULE_NAME)
    list (REMOVE_AT CONTENT_LINE 0)
    list (APPEND ${MODULE_LIST} ${MODULE_NAME})
    # (!) REMOVE THE LINE BELOW (implicit variables)
    set (${MODULE_NAME}_TOOLKITS ${CONTENT_LINE} PARENT_SCOPE)
  endforeach()

  set (${MODULE_LIST} ${${MODULE_LIST}} PARENT_SCOPE)
endfunction()

