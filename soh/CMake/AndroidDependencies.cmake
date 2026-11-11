# Android-only third-party dependencies for Ship of Harkinian + Archipelago.
#
# On desktop these come from vcpkg / system packages. The Android NDK has none of them,
# so they are fetched and built here for the ABI currently being configured by Gradle.
#
# Provides:
#   SOH_ANDROID_AUDIO_LIBS     - ogg, vorbis, vorbisfile, opus, opusfile targets
#   SOH_ANDROID_NETWORK_LIBS   - SDL2_net + OpenSSL (ssl, crypto) when BUILD_REMOTE_CONTROL is on
#   SOH_ANDROID_INCLUDE_DIRS   - extra include dirs (e.g. <opus/opus.h> compatibility)

include(FetchContent)
include(ExternalProject)

set(SOH_ANDROID_INCLUDE_DIRS "")

################################################################################
# Audio: libogg, libvorbis, libopus, opusfile (custom music / sequence support)
################################################################################
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(INSTALL_DOCS OFF CACHE BOOL "" FORCE)
set(INSTALL_PKG_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
set(INSTALL_CMAKE_PACKAGE_MODULE OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    ogg
    GIT_REPOSITORY https://github.com/xiph/ogg.git
    GIT_TAG v1.3.5
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(ogg)

FetchContent_Declare(
    vorbis
    GIT_REPOSITORY https://github.com/xiph/vorbis.git
    GIT_TAG v1.3.7
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(vorbis)

set(OPUS_BUILD_TESTING OFF CACHE BOOL "" FORCE)
set(OPUS_BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_PKG_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
set(OPUS_INSTALL_CMAKE_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
FetchContent_Declare(
    opus
    GIT_REPOSITORY https://github.com/xiph/opus.git
    GIT_TAG v1.5.2
    OVERRIDE_FIND_PACKAGE
)
FetchContent_MakeAvailable(opus)

# opusfile v0.12 only ships an autotools build, so build its four core sources here
# (no HTTP support, so no OpenSSL dependency).
FetchContent_Declare(
    opusfile
    GIT_REPOSITORY https://github.com/xiph/opusfile.git
    GIT_TAG v0.12
)
FetchContent_GetProperties(opusfile)
if(NOT opusfile_POPULATED)
    FetchContent_Populate(opusfile)
endif()
add_library(opusfile STATIC
    ${opusfile_SOURCE_DIR}/src/info.c
    ${opusfile_SOURCE_DIR}/src/internal.c
    ${opusfile_SOURCE_DIR}/src/opusfile.c
    ${opusfile_SOURCE_DIR}/src/stream.c
)
target_include_directories(opusfile PUBLIC ${opusfile_SOURCE_DIR}/include PRIVATE ${opusfile_SOURCE_DIR}/src)
target_compile_definitions(opusfile PRIVATE OP_DISABLE_HTTP)
target_link_libraries(opusfile PUBLIC opus ogg)

# SoH includes <opus/opus.h>, but the opus source tree keeps its headers directly in include/.
set(SOH_OPUS_COMPAT_DIR ${CMAKE_BINARY_DIR}/opus-compat)
file(GLOB SOH_OPUS_HEADERS ${opus_SOURCE_DIR}/include/*.h)
file(COPY ${SOH_OPUS_HEADERS} DESTINATION ${SOH_OPUS_COMPAT_DIR}/opus)
list(APPEND SOH_ANDROID_INCLUDE_DIRS ${SOH_OPUS_COMPAT_DIR} ${opusfile_SOURCE_DIR}/include)

set(SOH_ANDROID_AUDIO_LIBS ogg vorbis vorbisfile vorbisenc opus opusfile)

################################################################################
# Networking (Archipelago, Anchor, Crowd Control): SDL2_net + OpenSSL
################################################################################
set(SOH_ANDROID_NETWORK_LIBS "")

if (BUILD_REMOTE_CONTROL)
    # ---- SDL2_net ----
    set(SDL2NET_INSTALL OFF CACHE BOOL "" FORCE)
    set(SDL2NET_SAMPLES OFF CACHE BOOL "" FORCE)
    set(SDL2NET_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(
        SDL2_net
        GIT_REPOSITORY https://github.com/libsdl-org/SDL_net.git
        GIT_TAG release-2.2.0
    )
    FetchContent_MakeAvailable(SDL2_net)

    # SoH includes <SDL2/SDL_net.h>
    set(SOH_SDLNET_COMPAT_DIR ${CMAKE_BINARY_DIR}/sdlnet-compat)
    file(COPY ${sdl2_net_SOURCE_DIR}/SDL_net.h DESTINATION ${SOH_SDLNET_COMPAT_DIR}/SDL2)
    list(APPEND SOH_ANDROID_INCLUDE_DIRS ${SOH_SDLNET_COMPAT_DIR})

    if (TARGET SDL2_net::SDL2_net-static)
        list(APPEND SOH_ANDROID_NETWORK_LIBS SDL2_net::SDL2_net-static)
    elseif (TARGET SDL2_net::SDL2_net)
        list(APPEND SOH_ANDROID_NETWORK_LIBS SDL2_net::SDL2_net)
    else()
        list(APPEND SOH_ANDROID_NETWORK_LIBS SDL2_net)
    endif()

    # ---- OpenSSL (static), cross-compiled with OpenSSL's own Android targets ----
    # Requires perl and make on the build host (Linux, macOS or WSL).
    if (CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
        set(SOH_OPENSSL_TARGET android-arm64)
    elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
        set(SOH_OPENSSL_TARGET android-arm)
    elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
        set(SOH_OPENSSL_TARGET android-x86)
    elseif (CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
        set(SOH_OPENSSL_TARGET android-x86_64)
    else()
        message(FATAL_ERROR "Unsupported Android ABI for OpenSSL: ${CMAKE_ANDROID_ARCH_ABI}")
    endif()

    if (CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
        set(SOH_NDK_HOST_TAG darwin-x86_64)
    elseif (CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
        set(SOH_NDK_HOST_TAG windows-x86_64)
    else()
        set(SOH_NDK_HOST_TAG linux-x86_64)
    endif()

    if (DEFINED ANDROID_NDK)
        set(SOH_NDK_ROOT ${ANDROID_NDK})
    else()
        set(SOH_NDK_ROOT ${CMAKE_ANDROID_NDK})
    endif()
    if (DEFINED ANDROID_PLATFORM_LEVEL)
        set(SOH_ANDROID_API ${ANDROID_PLATFORM_LEVEL})
    else()
        set(SOH_ANDROID_API ${CMAKE_SYSTEM_VERSION})
    endif()

    find_program(SOH_PERL perl REQUIRED)
    find_program(SOH_MAKE NAMES make gmake REQUIRED)

    set(SOH_OPENSSL_PREFIX ${CMAKE_BINARY_DIR}/openssl-${CMAKE_ANDROID_ARCH_ABI})
    set(SOH_NDK_BIN ${SOH_NDK_ROOT}/toolchains/llvm/prebuilt/${SOH_NDK_HOST_TAG}/bin)
    set(SOH_OPENSSL_ENV
        ${CMAKE_COMMAND} -E env
        "ANDROID_NDK_ROOT=${SOH_NDK_ROOT}"
        "PATH=${SOH_NDK_BIN}:$ENV{PATH}"
    )

    ExternalProject_Add(
        openssl_android
        GIT_REPOSITORY https://github.com/openssl/openssl.git
        GIT_TAG openssl-3.0.15
        GIT_SHALLOW TRUE
        UPDATE_COMMAND ""
        BUILD_IN_SOURCE TRUE
        CONFIGURE_COMMAND
            ${SOH_OPENSSL_ENV} ${SOH_PERL} ./Configure ${SOH_OPENSSL_TARGET}
                -D__ANDROID_API__=${SOH_ANDROID_API}
                no-shared no-tests no-engine no-dso
                --prefix=${SOH_OPENSSL_PREFIX} --libdir=lib
        BUILD_COMMAND ${SOH_OPENSSL_ENV} ${SOH_MAKE} -j4 build_libs
        INSTALL_COMMAND ${SOH_OPENSSL_ENV} ${SOH_MAKE} install_dev
        BUILD_BYPRODUCTS
            ${SOH_OPENSSL_PREFIX}/lib/libssl.a
            ${SOH_OPENSSL_PREFIX}/lib/libcrypto.a
    )

    # Imported targets with the same names find_package(OpenSSL) would provide.
    file(MAKE_DIRECTORY ${SOH_OPENSSL_PREFIX}/include)
    add_library(OpenSSL::Crypto STATIC IMPORTED GLOBAL)
    set_target_properties(OpenSSL::Crypto PROPERTIES
        IMPORTED_LOCATION ${SOH_OPENSSL_PREFIX}/lib/libcrypto.a
        INTERFACE_INCLUDE_DIRECTORIES ${SOH_OPENSSL_PREFIX}/include
    )
    add_library(OpenSSL::SSL STATIC IMPORTED GLOBAL)
    set_target_properties(OpenSSL::SSL PROPERTIES
        IMPORTED_LOCATION ${SOH_OPENSSL_PREFIX}/lib/libssl.a
        INTERFACE_INCLUDE_DIRECTORIES ${SOH_OPENSSL_PREFIX}/include
        INTERFACE_LINK_LIBRARIES OpenSSL::Crypto
    )
    add_dependencies(OpenSSL::Crypto openssl_android)
    add_dependencies(OpenSSL::SSL openssl_android)

    set(OPENSSL_FOUND TRUE)
    set(OPENSSL_INCLUDE_DIR ${SOH_OPENSSL_PREFIX}/include)
    list(APPEND SOH_ANDROID_INCLUDE_DIRS ${SOH_OPENSSL_PREFIX}/include)
    list(APPEND SOH_ANDROID_NETWORK_LIBS OpenSSL::SSL OpenSSL::Crypto)
endif()
