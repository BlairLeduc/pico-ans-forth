# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Initialise pico_sdk from installed location
# (note this can come from environment, CMake cache etc)

# == DO NOT EDIT THE FOLLOWING LINES for the Raspberry Pi Pico VS Code Extension to work ==
if(WIN32)
    set(USERHOME $ENV{USERPROFILE})
else()
    set(USERHOME $ENV{HOME})
endif()
set(sdkVersion 2.1.1)
set(toolchainVersion 14_2_Rel1)
set(picotoolVersion 2.1.1)
set(picoVscode ${USERHOME}/.pico-sdk/cmake/pico-vscode.cmake)
if (EXISTS ${picoVscode})
    include(${picoVscode})
endif()
# ====================================================================================
set(PICO_BOARD pico2_w CACHE STRING "Board type")
set(PICO_DEOPTIMIZED_DEBUG ON)      # Disable optimizations.
set(PICO_ANS_FORTH_VERSION "1.0.0-alpha.3")

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(pico-ans-forth C CXX ASM)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

set(FORTH_SOURCES
    wordsets/block/core.S
    wordsets/core/arithmetic.S
    wordsets/core/character.S
    wordsets/core/comments.S
    wordsets/core/compiler.S
    wordsets/core/control.S
    wordsets/core/input-output.S
    wordsets/core/interpreter.S
    wordsets/core/logical.S
    wordsets/core/numeric.S
    wordsets/core/stack.S
    wordsets/double/core.S
    wordsets/exception/core.S
    wordsets/exception/extension.S
    wordsets/facility/core.S
    wordsets/facility/extension.S
    wordsets/string/core.S
    wordsets/tools/core.S
    dictionary.S
    forth.c
    forth.S)

# Add forth.inc as a dependency
set_source_files_properties(
    ${CMAKE_CURRENT_SOURCE_DIR}/forth.inc
    PROPERTIES HEADER_FILE_ONLY TRUE
)

# Make sure targets depending on forth.inc are rebuilt when it changes
set_property(
    SOURCE ${FORTH_SOURCES}
    APPEND PROPERTY OBJECT_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/forth.inc
)

# Add executable. Default name is the project name

add_executable(pico-ans-forth
    ${FORTH_SOURCES}
)

pico_set_program_name(pico-ans-forth "pico-ans-forth")
pico_set_program_url(pico-ans-forth "https://github.com/BlairLeduc/pico-ans-forth")
pico_set_program_version(pico-ans-forth "${PICO_ANS_FORTH_VERSION}")

# Modify the below lines to enable/disable output over UART/USB
#pico_enable_stdio_uart(pico-ans-forth 0)
#pico_enable_stdio_usb(pico-ans-forth 0)

configure_file(version.h.in version.h)

# Add the standard library to the build
target_link_libraries(pico-ans-forth
        pico_stdlib
        hardware_uart
)

# Add the standard include files to the build
target_include_directories(pico-ans-forth PRIVATE
        ${CMAKE_CURRENT_LIST_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
)

pico_add_extra_outputs(pico-ans-forth)

