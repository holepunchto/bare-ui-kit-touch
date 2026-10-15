cmake_minimum_required(VERSION 4.0)

find_package(cmake-bare REQUIRED PATHS node_modules/cmake-bare)

project(bare_ui_kit_touch C OBJC)

add_bare_module(bare_ui_kit_touch)

target_sources(
  ${bare_ui_kit_touch}
  PRIVATE
    binding.m
)

target_include_directories(
  ${bare_ui_kit_touch}
  PRIVATE
    node_modules/bare-foundation-registry/lib
)

target_link_libraries(
  ${bare_ui_kit_touch}
  PUBLIC
    "-framework UIKit"
    "-framework IOKit"
)
