# CDDL HEADER START
#
# This file and its contents are supplied under the terms of the
# Common Development and Distribution License ("CDDL"), version 1.0.
# You may only use this file in accordance with the terms of version
# 1.0 of the CDDL.
#
# A full copy of the text of the CDDL should have accompanied this
# source.  A copy of the CDDL is also available via the Internet at
# http://www.illumos.org/license/CDDL.
#
# CDDL HEADER END

# Copyright 2022 Saso Kiselkov. All rights reserved.

cmake_minimum_required(VERSION 3.0)

project(libradio)

option(LIBACFUTILS_SRC	"libacfutils source path")
if(${LIBACFUTILS_SRC} STREQUAL "OFF")
	message("Missing LIBACFUTILS_SRC option. Call cmake -LIBACFUTILS_SRC=<path>")
	return()
endif()

option(LIBACFUTILS_REDIST	"libacfutils redist path")
if(${LIBACFUTILS_REDIST} STREQUAL "OFF")
	message("Missing LIBACFUTILS_REDIST option. Call cmake -LIBACFUTILS_REDIST=<path>")
	return()
endif()

option(OPENGPWS		"OpenGPWS source path")
if(${OPENGPWS} STREQUAL "OFF")
	message("Missing OPENGPWS option. Call cmake -DOPENGPWS=<path>")
	return()
endif()

option(BACKEND		"Is libradio a simple backend to another systems sim?")

option(APCTL		"Should libradio control the X-Plane autopilot?")
if(${APCTL} STREQUAL "OFF")
	set(APCTL	"0")
endif()

option(OPENGPWS_CTL	"Should libradio control OpenGPWS?")
if(${OPENGPWS_CTL} STREQUAL "OFF")
	set(OPENGPWS_CTL "0")
endif()

option(DEF_CLAMP	"Clamp CDI deflection to +/- 2.0 dots?")
if(${DEF_CLAMP} STREQUAL "OFF")
	set(DEF_CLAMP	"0")
endif()

# Platform-specific variables
if(APPLE)
	set(PLAT_SHORT "mac64")
	set(PLAT_LONG "mac-64")
elseif(WIN32)
	set(PLAT_SHORT "mingw64")
	set(PLAT_LONG "win-64")
else()
	set(PLAT_SHORT "lin64")
	set(PLAT_LONG "linux-64")
endif()

# Build path setup
file(GLOB GLEW_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB OPENAL_PREFIX "${LIBACFUTILS_SRC}/openal-soft/openal-soft-1.21.0-${PLAT_LONG}/build/install")
file(GLOB CAIRO_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB PIXMAN_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB FREETYPE_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB OPUSFILE_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB LIBOGG_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB OPENSSL_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")
file(GLOB ICONV_PREFIX "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib")

file(GLOB SRC
    *.c
    ../src/*.c
    ../src/*.cc
    )
file(GLOB HDR
    *.h
    ../src/libradio/*.h
    )

set(ALL_SRC ${SRC} ${HDR})
list(SORT ALL_SRC)

add_library(libradio STATIC ${ALL_SRC})

include_directories(libradio PUBLIC
    "${CMAKE_SOURCE_DIR}/../src"
    "${CMAKE_SOURCE_DIR}/../src/libradio"
    "${LIBACFUTILS_REDIST}/include"
	"${LIBACFUTILS_REDIST}/${PLAT_SHORT}/include"
    "${LIBACFUTILS_SRC}/SDK/CHeaders/XPLM"
    "${LIBACFUTILS_SRC}/SDK/CHeaders/Widgets"
    "${LIBACFUTILS_SRC}/SDK/CHeaders/Wrappers"
    "${OPENAL_PREFIX}/include/AL"
    "${CAIRO_PREFIX}/include/cairo"
    "${FREETYPE_PREFIX}/include/freetype2"
    "${GLEW_PREFIX}/include"
    "${OPENGPWS}/api"
    )

# Compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra -Werror --std=c11 \
    -Wno-unused-local-typedefs -fvisibility=hidden")
if(APPLE)
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -arch x86_64 -arch arm64 \
	    -Wno-deprecated")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -arch x86_64 -arch arm64 \
	    -Wno-deprecated")
else()
	set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-missing-field-initializers")
endif()

# Yes, we need to strip a trailing newline from command output. CMake is
# "smart" like that...
execute_process(COMMAND git describe --abbrev=0 --tags
    OUTPUT_VARIABLE PLUGIN_VERSION)
string(REGEX REPLACE "\n$" "" PLUGIN_VERSION "${PLUGIN_VERSION}")

# Defines
add_definitions(-D_GNU_SOURCE)
add_definitions(-D_FILE_OFFSET_BITS=64)
add_definitions(-DDEBUG)
add_definitions(-DGLEW_BUILD=GLEW_STATIC -DGLEW_MX)
add_definitions(-DAL_LIBTYPE_STATIC)
add_definitions("-DCHECK_RESULT_USED=__attribute__((warn_unused_result))")
add_definitions(-DPLUGIN_VERSION="${PLUGIN_VERSION}")

add_definitions(-DLIBRADIO_APCTL=${APCTL})
add_definitions(-DLIBRADIO_OPENGPWS_CTL=${OPENGPWS_CTL})
add_definitions(-DLIBRADIO_DEF_CLAMP=${DEF_CLAMP})
if(${BACKEND})
	add_definitions(-DLIBRADIO_BACKEND)
endif()


add_definitions(-DXPLM200=1 -DXPLM210=1 -DXPLM300=1 -DXPLM301=1 -DXPLM302=1 -DXPLANE)
if(APPLE)
	add_definitions(-DAPL=1 -DIBM=0 -DLIN=0)
elseif(WIN32)
	add_definitions(-DAPL=0 -DIBM=1 -DLIN=0 -D_WIN32_WINNT=0x0600)
else()
	add_definitions(-DAPL=0 -DIBM=0 -DLIN=1)
endif()

# Linking
# Careful: order matters in target_link_libraries. Dependencies must be
# ordered as first symbol callers and then as symbol providers (i.e.
# libpng16 depends on libz, so linking must be first: libpng, then libz).
link_libraries(m)
file(GLOB LIBACFUTILS_LIBRARY "${LIBACFUTILS_REDIST}/${PLAT_SHORT}/lib/libacfutils.a")
file(GLOB LIBPNG_LIBRARY "${LIBPNG_PREFIX}/lib/libpng16.a")
file(GLOB ZLIB_LIBRARY "${LIBACFUTILS}/zlib/zlib-${PLAT_LONG}/lib/libz.a")
file(GLOB OPUSFILE_LIBRARY  "${OPUSFILE_PREFIX}/lib/libopusfile.a")
file(GLOB OPUS_LIBRARY "${LIBACFUTILS}/opus/opus-${PLAT_LONG}/lib/libopus.a")
file(GLOB OGG_LIBRARY "${LIBOGG_PREFIX}/lib/libogg.a")
if(WIN32)
	file(GLOB OPENAL_LIBRARY "${OPENAL_PREFIX}/lib/libOpenAL32.a")
else()
	file(GLOB OPENAL_LIBRARY "${OPENAL_PREFIX}/lib/libopenal.a")
endif()
file(GLOB FREETYPE_LIBRARY "${FREETYPE_PREFIX}/lib/libfreetype.a")
file(GLOB CAIRO_LIBRARY "${CAIRO_PREFIX}/lib/libcairo.a")
file(GLOB PIXMAN_LIBRARY  "${PIXMAN_PREFIX}/lib/libpixman-1.a")

if(WIN32)
	file(GLOB GLEW_LIBRARY "${GLEW_PREFIX}/lib/libglew32mx.a")
elseif(APPLE)
	file(GLOB GLEW_LIBRARY "${GLEW_PREFIX}/lib/libGLEWmx.a")
else()
	file(GLOB GLEW_LIBRARY "${GLEW_PREFIX}/lib64/libGLEWmx.a")
endif()
file(GLOB CURL_LIBRARY "${LIBACFUTILS}/curl/libcurl-${PLAT_LONG}/lib/libcurl.a")
file(GLOB OPENSSL_LIBRARY "${OPENSSL_PREFIX}/lib/libssl.a")
file(GLOB CRYPTO_LIBRARY "${OPENSSL_PREFIX}/lib/libcrypto.a")
file(GLOB ICONV_LIBRARY "${ICONV_PREFIX}/lib/libiconv.a")

if(APPLE)
	find_library(XPLM_FRAMEWORK XPLM "${LIBACFUTILS_SRC}/SDK/Libraries/Mac")
	find_library(XPWIDGETS_FRAMEWORK XPWidgets
	    "${LIBACFUTILS_SRC}/SDK/Libraries/Mac")
	find_library(OPENGL_FRAMEWORK OpenGL)
	find_library(AUDIOUNIT_FRAMEWORK AudioUnit)
	find_library(COREAUDIO_FRAMEWORK CoreAudio)
	find_library(COCOA_FRAMEWORK Cocoa)
	set(EXTRA_PLATFORM_LIBS
	    ${XPLM_FRAMEWORK}
	    ${XPWIDGETS_FRAMEWORK}
	    ${OPENGL_FRAMEWORK}
	    ${COCOA_FRAMEWORK}
	    ${AUDIOUNIT_FRAMEWORK}
	    ${COREAUDIO_FRAMEWORK}
	    )
elseif(WIN32)
	find_library(XPLM_LIBRARY XPLM_64 "${LIBACFUTILS_SRC}/SDK/Libraries/Win")
	find_library(XPWIDGETS_LIBRARY XPWidgets_64
	    "${LIBACFUTILS_SRC}/SDK/Libraries/Win")
	set(EXTRA_PLATFORM_LIBS
	    ${XPLM_LIBRARY}
	    ${XPWIDGETS_LIBRARY}
	    "-lglu32"
	    "-lopengl32"
	    "-lws2_32"
	    "-lwinmm"
	    "-ldbghelp"
	    "-lpsapi"
	    "-lcrypt32"
	    "-lbcrypt"
	    )
else()
	set(EXTRA_PLATFORM_LIBS "")
endif()

target_link_libraries(libradio
    ${LIBACFUTILS_LIBRARY}
    ${CAIRO_LIBRARY}
    ${PIXMAN_LIBRARY}
    ${FREETYPE_LIBRARY}
    ${LIBPNG_LIBRARY}
    ${GLEW_LIBRARY}
    ${OPENAL_LIBRARY}
    ${OPUSFILE_LIBRARY}
    ${OPUS_LIBRARY}
    ${OGG_LIBRARY}
    ${CURL_LIBRARY}
    ${OPENSSL_LIBRARY}
    ${CRYPTO_LIBRARY}
    ${ICONV_LIBRARY}
    ${ZLIB_LIBRARY}
    ${EXTRA_PLATFORM_LIBS}
    )

set_target_properties(libradio PROPERTIES PREFIX "")

if(APPLE)
	set_target_properties(libradio PROPERTIES LINK_FLAGS
	    "${CMAKE_SHARED_LINKER_FLAGS} -fvisibility=hidden -bundle \
	    -arch x86_64 -arch arm64")
elseif(WIN32)
	set_target_properties(libradio PROPERTIES LINK_FLAGS
	    "${CMAKE_SHARED_LINKER_FLAGS} -undefined_warning \
	    -fvisibility=hidden -static-libgcc -static-libstdc++")
else()
	set_target_properties(libradio PROPERTIES LINK_FLAGS
	    "${CMAKE_SHARED_LINKER_FLAGS} -rdynamic -nodefaultlibs \
	    -undefined_warning -fPIC -fvisibility=hidden \
	    -static-libgcc -static-libstdc++")
endif()
set_target_properties(libradio PROPERTIES LINKER_LANGUAGE CXX)

set_target_properties(libradio PROPERTIES ARCHIVE_OUTPUT_DIRECTORY
    "${CMAKE_SOURCE_DIR}/lib/${PLAT_SHORT}")
