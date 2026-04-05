cmake_minimum_required(VERSION 3.13)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

APPLY_STANDARD_SETTINGS(${BINARY_NAME})

target_compile_definitions(${BINARY_NAME} PRIVATE "APPLICATION_ID=\"${APPLICATION_ID}\"")

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/resources/musicvids_studio.desktop"
  DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
  COMPONENT Runtime)
