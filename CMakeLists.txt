cmake_minimum_required(VERSION 3.4.0)
project(Dyninst-TestSuite)

set(Dyninst_DIR $ENV{Dyninst_DIR} CACHE PATH "Location of Dyninst cmake files")
set(Dyninst_SRC_DIR $ENV{Dyninst_SRC_DIR} CACHE PATH "Location of Dyninst source files")

# Import the system threads library
find_package(Threads)

if(Dyninst_DIR)
# Read the cache generated from building Dyninst
load_cache(${Dyninst_DIR}
           Boost_SYSTEM_LIBRARY_RELEASE
           Boost_INCLUDE_DIRS
           Boost_LIBRARY_DIRS
           Boost_DEFINES
           TBB_INCLUDE_DIRS
           TBB_LIBRARY_DIRS
           TBB_DEFINES
           ElfUtils_INCLUDE_DIRS
           ElfUtils_LIBRARY_DIRS
           )
set(CMAKE_MODULE_PATH
    ${CMAKE_MODULE_PATH}
    "${PROJECT_SOURCE_DIR}/cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Modules"
    "${Dyninst_DIR}"
    "${Dyninst_DIR}/Modules")
elseif(Dyninst_SRC_DIR)
# Use a search path to find all the bits
set(CMAKE_MODULE_PATH
    ${CMAKE_MODULE_PATH}
    "${PROJECT_SOURCE_DIR}/cmake"
    "${PROJECT_SOURCE_DIR}/cmake/Modules"
    "${Dyninst_SRC_DIR}/cmake"
    "${Dyninst_SRC_DIR}/cmake/Modules")
include(ElfUtils)
include(ThreadingBuildingBlocks)
include(Boost)
if(${CMAKE_VERSION} VERSION_GREATER_EQUAL "3.12")
cmake_policy(SET CMP0074 NEW)
endif()
set(DYNINST_ROOT ${Dyninst_SRC_DIR})
include(${Dyninst_SRC_DIR}/cmake/platform.cmake)
include(${Dyninst_SRC_DIR}/cmake/cap_arch_def.cmake)
set(DYNINST_PLATFORM ${PLATFORM})
set(DYNINST_INTERNAL_DEFINES ${UNIFIED_DEFINES})
else()
message(FATAL_ERROR "One of Dyninst[_SRC]_DIR must be set!")
endif()

# Import the include and library directory names
# NB: TBB and ElfUtils are not (currently) used directly in
#     Testsuite, but are transitively included from headers
#     in Dyninst.
include_directories(${Boost_INCLUDE_DIRS})
link_directories(${Boost_LIBRARY_DIRS})
add_definitions(${Boost_DEFINES})

include_directories(${TBB_INCLUDE_DIRS})
link_directories(${TBB_LIBRARY_DIRS})
add_definitions(${TBB_DEFINES})

include_directories(${ElfUtils_INCLUDE_DIRS})
link_directories(${ElfUtils_LIBRARY_DIRS})

include(c++11.cmake)
include(LibXml2)

include_directories(${LibXml2_INCLUDE_DIRS})
link_directories(${LibXml2_LIBRARY_DIRS})

set(USE_CXX11_ABI "" CACHE STRING "Override the default GNU C++11 ABI setting")
if(NOT ("${USE_CXX11_ABI}" STREQUAL ""))
  if(${USE_CXX11_ABI})
    add_definitions(-D_GLIBCXX_USE_CXX11_ABI=1)
  else()
    add_definitions(-D_GLIBCXX_USE_CXX11_ABI=0)
  endif()
endif()

if(CMAKE_COMPILER_IS_GNUCXX OR ${CMAKE_C_COMPILER_ID} MATCHES Clang)
  set(CMAKE_C_FLAGS_DEBUG "-O0 -g")
  set(CMAKE_C_FLAGS_RELEASE "-O2")
  set(CMAKE_CXX_FLAGS_DEBUG "-O0 -g")
  set(CMAKE_CXX_FLAGS_RELEASE "-O2")
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "-O2 -g")
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "-O2 -g")
else(MSVC)
  set(CMAKE_C_FLAGS_DEBUG "/Od /Zi /MDd /D_DEBUG")
  set(CMAKE_C_FLAGS_RELEASE "/O2 /MD /D NDEBUG")
  set(CMAKE_CXX_FLAGS_DEBUG "/Od /Zi /MDd /D_DEBUG")
  set(CMAKE_CXX_FLAGS_RELEASE "/O2 /MD /D NDEBUG")
  set(CMAKE_C_FLAGS_RELWITHDEBINFO "/O2 /Zi /MD /D NDEBUG")
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "/O2 /Zi /MD /D NDEBUG")
endif()

# CMake tries to auto-add flags to link lines, which isn't helpful.  Blanking
# this variable should fix.
set(CMAKE_SHARED_LIBRARY_LINK_C_FLAGS "")
set(CMAKE_SHARED_LIBRARY_LINK_CXX_FLAGS "")

find_package(Dyninst REQUIRED
             COMPONENTS common
             OPTIONAL_COMPONENTS symtabAPI
                                 dyninstAPI
                                 instructionAPI
                                 proccontrol)

message(STATUS "Dyninst includes: ${DYNINST_INCLUDE_DIR}")
include_directories(${DYNINST_INCLUDE_DIR})
message(STATUS "Project source dir: ${PROJECT_SOURCE_DIR}")
set(BUILD_SHARED_LIBS ON)

if("${DYNINST_PLATFORM}" MATCHES "bgq")
  find_package(LaunchMON REQUIRED)
  include_directories(${LAUNCHMON_INCLUDE_DIR})
  add_definitions(${LAUNCHMON_DEFINITIONS})
endif()

set(INSTALL_DIR "bin/testsuite" CACHE PATH "Testsuite installation directory")

# Build rules for the test libraries (libtestdyninst, libtestproccontrol, etc.)
# and the executables

if(UNIX)
  enable_language(ASM-ATT)
  if("${DYNINST_PLATFORM}" MATCHES "i386")
    enable_language(ASM_NASM)
  endif()
elseif(WIN32)
  enable_language(ASM_MASM)
  if(CMAKE_C_COMPILER_VERSION VERSION_GREATER 19)
    add_definitions(-D_SILENCE_STDEXT_HASH_DEPRECATION_WARNINGS=1)
  else()
    add_definitions(-Dsnprintf=_snprintf)
  endif()
endif()

foreach(def ${DYNINST_INTERNAL_DEFINES})
  # add_definitions doesn't seem to get pulled in; that's okay, since we don't
  # want it anyway (we want to override for mutators/ees)
  add_definitions(${def}_test)
  set(MUTATEE_DEFINES "${MUTATEE_DEFINES} ${def}_test")
endforeach()

include_directories(src
                    src/dyninst
                    src/proccontrol
                    src/symtab
                    src/instruction)

set(LIBTESTSUITE_COMMON_SRCS
    src/test_lib.C
    src/TestData.C
    src/TestMutator.C
    src/TestOutputDriver.C
    src/StdOutputDriver.C
    src/remotetest.C
    src/connection.C
    src/ParameterDict.C
    src/module.C
    src/ResumeLog.C
    src/test_lib_templates.C
    src/JUnitOutputDriver.cpp
    src/UsageMonitor.C)

set(LIBTESTLAUNCH_SRCS
    src/CmdLine.C
    src/ParameterDict.C
    src/ResumeLog.C
    src/MutateeStart.C
    src/test_info_new.C
    ${DYNINST_PLATFORM}/test_info_new.gen.C
    src/UsageMonitor.C
    src/TestOutputDriver.C
    src/StdOutputDriver.C
    src/JUnitOutputDriver.cpp)

if(UNIX)
  add_library(testSuite
              SHARED
              src/test_lib_soExecution.C
              ${LIBTESTSUITE_COMMON_SRCS})
  add_library(testlaunch SHARED ${LIBTESTLAUNCH_SRCS})
  target_link_libraries(testlaunch ${LibXml2_LIBRARIES} testSuite)
  set(TESTSUITE_TESTLAUNCH_LINK testSuite testlaunch)
else()
  add_library(testSuite
              SHARED
              src/test_lib_dllExecution.C
              ${LIBTESTSUITE_COMMON_SRCS}
              ${LIBTESTLAUNCH_SRCS})
  set(TESTSUITE_TESTLAUNCH_LINK testSuite)
endif()
add_dependencies(testSuite LibXml2)

set_target_properties(${TESTSUITE_TESTLAUNCH_LINK}
                      PROPERTIES COMPILE_DEFINITIONS TESTLIB_DLL_BUILD)

target_link_libraries(testSuite ${CMAKE_DL_LIBS} ${LibXml2_LIBRARIES})

add_library(DatabaseOutputDriver SHARED src/DatabaseOutputDriver.C)
target_link_libraries(DatabaseOutputDriver testSuite)
set_target_properties(DatabaseOutputDriver PROPERTIES PREFIX "")

if(WIN32)
  set_target_properties(DatabaseOutputDriver
                        PROPERTIES COMPILE_DEFINITIONS os_windows_test)
  target_link_libraries(DatabaseOutputDriver ws2_32)
endif()

if(WIN32)
  set(PLAT_SRC)
else()
  set(PLAT_SRC
      src/dyninst/ParseThat.C
      src/dyninst/test_lib_test7.C
      src/dyninst/test_lib_test9.C)
endif()

set(COMPLIB_DEFS TESTLIB_DLL_BUILD COMPLIB_DLL_BUILD)

if(TARGET dyninstAPI)
  add_library(testdyninst
              SHARED
              src/dyninst/dyninst_comp.C
              src/dyninst/test_lib_mutateeStart.C
              src/dyninst/Callbacks.C
              src/dyninst/Process_data.C
              ${PLAT_SRC})
  target_link_libraries(testdyninst
                        testlaunch
                        testSuite
                        dyninstAPI
                        instructionAPI
                        common
                        ${Boost_SYSTEM_LIBRARY_RELEASE}
                        ${CMAKE_THREAD_LIBS_INIT})
  install(TARGETS testdyninst DESTINATION ${INSTALL_DIR})
  set_target_properties(testdyninst
                        PROPERTIES COMPILE_DEFINITIONS "${COMPLIB_DEFS}")
endif()

if(TARGET symtabAPI)
  add_library(testsymtab SHARED src/symtab/symtab_comp.C)
  target_link_libraries(testsymtab
                        testSuite
                        symtabAPI
                        common
                        ${Boost_SYSTEM_LIBRARY_RELEASE}
                        ${CMAKE_THREAD_LIBS_INIT})
  install(TARGETS testsymtab DESTINATION ${INSTALL_DIR})
  set_target_properties(testsymtab
                        PROPERTIES COMPILE_DEFINITIONS "${COMPLIB_DEFS}")
endif()

if(TARGET instructionAPI)
  add_library(testinstruction SHARED src/instruction/instruction_comp.C)
  target_link_libraries(testinstruction
                        testSuite
                        instructionAPI
                        symtabAPI
                        common
                        ${Boost_SYSTEM_LIBRARY_RELEASE}
                        ${CMAKE_THREAD_LIBS_INIT})
  install(TARGETS testinstruction DESTINATION ${INSTALL_DIR})
  set_target_properties(testinstruction
                        PROPERTIES COMPILE_DEFINITIONS "${COMPLIB_DEFS}")
endif()

if(TARGET pcontrol)
  add_library(testproccontrol SHARED src/proccontrol/proccontrol_comp.C)

  if(WIN32)
    target_link_libraries(testproccontrol
                          testSuite
                          pcontrol
                          common
                          ${CMAKE_THREAD_LIBS_INIT}
                          ws2_32)
  else()
    target_link_libraries(testproccontrol
                          testlaunch
                          testSuite
                          pcontrol
                          common
                          ${Boost_SYSTEM_LIBRARY_RELEASE}
                          ${CMAKE_THREAD_LIBS_INIT})
  endif()
  install(TARGETS testproccontrol DESTINATION ${INSTALL_DIR})
  set_target_properties(testproccontrol
                        PROPERTIES COMPILE_DEFINITIONS "${COMPLIB_DEFS}")
endif()

if(WIN32)
  set(RUNTESTS_UTILS src/runTests-utils-nt.C)
else()
  set(RUNTESTS_UTILS src/runTests-utils.C)
endif()

if(WIN32)
  set(TD_BE)
else()
  set(TD_BE src/testdriver_be.C)
endif()

add_executable(runTests
               src/runTests.C
               ${RUNTESTS_UTILS}
               src/test_driver_templates.C)
target_link_libraries(runTests)

add_executable(test_driver
               src/test_driver.C
               src/test_driver_templates.C
               src/dynlmon.C
               ${TD_BE}
               ${DYNINST_PLATFORM}/test_info_new.gen.C)
target_link_libraries(test_driver ${TESTSUITE_TESTLAUNCH_LINK})

if(LAUNCHMON_FE_LIBRARIES)
  target_link_libraries(test_driver ${LAUNCHMON_FE_LIBRARIES})
  target_link_libraries(test_driver ${LAUNCHMON_BE_LIBRARIES})
endif()

if(WIN32)

else()
  add_executable(testdriver_wrapper src/connection.C src/testdriver_wrapper.C)
  install(TARGETS testdriver_wrapper DESTINATION ${INSTALL_DIR})
endif()

install(TARGETS test_driver
                runTests
                ${TESTSUITE_TESTLAUNCH_LINK}
                DatabaseOutputDriver
        DESTINATION ${INSTALL_DIR})

include(${DYNINST_PLATFORM}/cmake-mutators.txt)

foreach(m ${MUTATOR_NAME_LIST})
  file(APPEND ${CMAKE_BINARY_DIR}/test_names.txt "${m}\n")
endforeach()

if(UNIX)
  # Compiler macros
  find_program(M_gnu_cc NAMES gcc)
  message(STATUS "Mutatee gcc: ${M_gnu_cc}")
  find_program(M_gnu_cxx NAMES g++)
  message(STATUS "Mutatee g++: ${M_gnu_cxx}")
  find_program(M_intel_cc NAMES icc)
  message(STATUS "Mutatee icc: ${M_intel_cc}")
  find_program(M_intel_CC NAMES icpc)
  message(STATUS "Mutatee icpc: ${M_intel_CC}")
  find_program(M_pg_cc NAMES pgcc)
  message(STATUS "Mutatee pgcc: ${M_pg_cc}")
  find_program(M_pg_cxx NAMES pgCC)
  message(STATUS "Mutatee pgCC: ${M_pg_cxx}")
  find_program(M_mpi_cc NAMES mpicc)
  message(STATUS "Mutatee mpicc: ${M_mpi_cc}")
  find_program(M_mpi_cxx NAMES mpicxx)
  message(STATUS "Mutatee mpicxx: ${M_mpi_cxx}")
  find_program(M_mpi_xlc NAMES mpixlc)
  message(STATUS "Mutatee mpixlc: ${M_mpi_xlc}")
  find_program(M_mpi_xlcxx NAMES mpixlcxx)
  message(STATUS "Mutatee mpixlcxx: ${M_mpi_xlcxx}")
elseif(WIN32)
  find_program(M_native_cc NAMES cl)
  find_program(M_native_cxx NAMES cl)
  find_program(M_native_linker NAMES link)
endif()

include(checkMutateeCompiler.cmake)

add_library(testA SHARED src/libtestA.c)
add_library(testA_static STATIC src/libtestA.c)
add_library(testB SHARED src/libtestB.c)
add_library(testB_static STATIC src/libtestB.c)
set_target_properties(testA_static PROPERTIES OUTPUT_NAME testA)
set_target_properties(testB_static PROPERTIES OUTPUT_NAME testB)

if(UNIX)
  add_library(Test12 SHARED src/dyninst/libTest12.c)
  install(TARGETS Test12
          LIBRARY DESTINATION ${INSTALL_DIR}
          RUNTIME DESTINATION ${INSTALL_DIR}
          ARCHIVE DESTINATION ${INSTALL_DIR})
endif()

install(TARGETS testA
                testB
                testA_static
                testB_static
        LIBRARY DESTINATION ${INSTALL_DIR}
        RUNTIME DESTINATION ${INSTALL_DIR}
        ARCHIVE DESTINATION ${INSTALL_DIR})

if(UNIX)
  check_mutatee_compiler(gcc "-m32" "-m32" C "" m32_works)
  if(${m32_works})
    message(STATUS "Building 32-bit helper libraries")
    add_library(testA_m32 SHARED src/libtestA.c)
    add_library(testB_m32 SHARED src/libtestB.c)
    add_library(testA_m32_static STATIC src/libtestA.c)
    add_library(testB_m32_static STATIC src/libtestB.c)
    set_target_properties(testA_m32_static PROPERTIES OUTPUT_NAME testA_m32)
    set_target_properties(testB_m32_static PROPERTIES OUTPUT_NAME testB_m32)

    install(TARGETS testA_m32
                    testB_m32
                    testA_m32_static
                    testB_m32_static
            LIBRARY DESTINATION ${INSTALL_DIR}
            ARCHIVE DESTINATION ${INSTALL_DIR})

    set_target_properties(testA_m32 testA_m32_static
                          PROPERTIES COMPILE_FLAGS
                                     "-m32 -Dm32_test"
                                     LINK_FLAGS
                                     "-m32")
    set_target_properties(testB_m32 testB_m32_static
                          PROPERTIES COMPILE_FLAGS
                                     "-m32 -Dm32_test"
                                     LINK_FLAGS
                                     "-m32")
  endif()
endif()

include(${DYNINST_PLATFORM}/cmake-mutatees.txt)
