# FindDyninst.cmake
# -----------------
#
# ... Dyninst_ROOT etc. ...
# A heart surgery wrapper for the Dyninst CMake cache.

# Hunt down the include dir first
find_path(Dyninst_INCLUDE_DIR Symtab.h)
set(DYNINST_INCLUDE_DIR ${Dyninst_INCLUDE_DIR})
set(Dyninst_INCLUDE_DIRS ${Dyninst_INCLUDE_DIR})

include(FindPackageHandleStandardArgs)

# The libraries are split by component, handle them individually.
set(Dyninst_LIBRARIES)
foreach(comp common symtabAPI dyninstAPI instructionAPI proccontrol)
  # Find the library itself
  find_library(Dyninst_${comp}_LIBRARY ${comp})
  if(Dyninst_${comp}_LIBRARY)
    set(Dyninst_LIBRARIES ${Dyninst_LIBRARIES} ${Dyninst_${comp}_LIBRARY})
    set(Dyninst_${comp}_FOUND True)
    # We also expose it as a target. Because changing the rest to actually do
    # something reasonable would really be heart surgery.
    add_library(${comp} SHARED IMPORTED)
    set_property(TARGET ${comp}
      PROPERTY IMPORTED_LOCATION ${Dyninst_${comp}_LIBRARY})
  endif()
endforeach(comp)

# Finalize the variables
find_package_handle_standard_args(Dyninst
  REQUIRED_VARS Dyninst_INCLUDE_DIR
  HANDLE_COMPONENTS)
