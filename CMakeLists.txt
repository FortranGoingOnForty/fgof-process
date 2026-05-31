cmake_minimum_required(VERSION 3.25)

project(fgof_process VERSION 0.1.1 LANGUAGES Fortran C)

add_library(fgof_process
  src/fgof_process_types.f90
  src/fgof_process_posix.f90
  src/fgof_process.f90
  src/fgof_process_posix.c
)
add_library(fgof::process ALIAS fgof_process)

set_target_properties(fgof_process PROPERTIES
  Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/mod"
)

target_include_directories(fgof_process PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/mod>
)

target_compile_options(fgof_process PRIVATE
  $<$<COMPILE_LANG_AND_ID:Fortran,GNU>:-std=f2018 -Wall -Wextra -Wpedantic -Werror>
  $<$<COMPILE_LANG_AND_ID:C,GNU,Clang,AppleClang>:-Wall -Wextra -Wpedantic -Werror>
)
