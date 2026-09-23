# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(MediaFlow LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "MediaFlow")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Windows-only local Browser Network Observation helper. The public Flutter
# BrowserAdapter contract remains unchanged; this executable is started only by
# the named Douyin fallback.
set(MEDIAFLOW_OBSERVATION_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../tools/browser_network_observation")
set(MEDIAFLOW_WEBVIEW2_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party/webview2")
set(MEDIAFLOW_OBSERVATION_OUT "${CMAKE_CURRENT_BINARY_DIR}/MediaFlowNetworkObservationHelper.exe")
file(TO_NATIVE_PATH "${MEDIAFLOW_OBSERVATION_OUT}" MEDIAFLOW_OBSERVATION_OUT_NATIVE)
file(TO_NATIVE_PATH "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/NetworkObservationPolicy.cs" MEDIAFLOW_POLICY_SOURCE_NATIVE)
file(TO_NATIVE_PATH "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/NetworkObservationHelper.cs" MEDIAFLOW_HELPER_SOURCE_NATIVE)
file(TO_NATIVE_PATH "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/WindowsPipeInput.cs" MEDIAFLOW_PIPE_SOURCE_NATIVE)
file(TO_NATIVE_PATH "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.Core.dll" MEDIAFLOW_WEBVIEW2_CORE_NATIVE)
file(TO_NATIVE_PATH "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.WinForms.dll" MEDIAFLOW_WEBVIEW2_WINFORMS_NATIVE)
add_custom_command(
  OUTPUT "${MEDIAFLOW_OBSERVATION_OUT}"
  COMMAND "C:/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    /nologo /target:exe /platform:x64
    /out:${MEDIAFLOW_OBSERVATION_OUT_NATIVE}
    /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.Web.Extensions.dll
    /r:${MEDIAFLOW_WEBVIEW2_CORE_NATIVE}
    /r:${MEDIAFLOW_WEBVIEW2_WINFORMS_NATIVE}
    "${MEDIAFLOW_POLICY_SOURCE_NATIVE}"
    "${MEDIAFLOW_HELPER_SOURCE_NATIVE}"
    "${MEDIAFLOW_PIPE_SOURCE_NATIVE}"
  DEPENDS
    "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/NetworkObservationPolicy.cs"
    "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/NetworkObservationHelper.cs"
    "${MEDIAFLOW_OBSERVATION_SOURCE_DIR}/WindowsPipeInput.cs"
    "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.Core.dll"
    "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.WinForms.dll"
  VERBATIM)
add_custom_target(mediaflow_network_observation_helper ALL
  DEPENDS "${MEDIAFLOW_OBSERVATION_OUT}")
add_dependencies(${BINARY_NAME} mediaflow_network_observation_helper)


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES
  "${MEDIAFLOW_OBSERVATION_OUT}"
  "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.Core.dll"
  "${MEDIAFLOW_WEBVIEW2_DIR}/Microsoft.Web.WebView2.WinForms.dll"
  "${MEDIAFLOW_WEBVIEW2_DIR}/WebView2Loader.dll"
  "${MEDIAFLOW_WEBVIEW2_DIR}/LICENSE.txt"
  DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
