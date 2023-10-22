#!/bin/bash
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

while getopts "s:r:g:h:" opt; do
	case $opt in
	s)
		LIBACFUTILS_SRC="$OPTARG"
		;;
	r)
		LIBACFUTILS_REDIST="$OPTARG"
		;;
	g)
		OPENGPWS="$OPTARG"
		;;
	h)
		cat << EOF
Usage: $0 [-nh] -s <libacfutils_src> -r <libacfutils_redist> -g <opengpws>
    -h : shows the current help screen
    -s <libacfutils_src> : the path to the built libacfutils repo (usually $LIBACFUTILS_SRC)
    -r <libacfutils_redist> : the path to the libacfutils redist (usually $LIBACFUTILS_REDIST)
    -g <opengpws> : the path to the OpenGPWS repo (only used for headers) (usually $OPENGPWS)
EOF
		exit
		;;
	*)
		"Unknown argument $opt. Try $0 -h for help." >&2
		exit 1
		;;
	esac
done

CMAKE_OPTS="-DBACKEND=0 -DAPCTL=0 -DOPENGPWS_CTL=1 -DDEF_CLAMP=0 -DCMAKE_BUILD_TYPE=Release"

if [ -z "$LIBACFUTILS_SRC" ]; then
	echo "Missing -s argument. Try $0 -h for help" >&2
	exit 1
fi

if [ -z "$LIBACFUTILS_REDIST" ]; then
	echo "Missing -r argument. Try $0 -h for help" >&2
	exit 1
fi

if [ -z "$OPENGPWS" ]; then
	echo "Missing -g argument. Try $0 -h for help" >&2
	exit 1
fi

set -e

case "$(uname)" in
Darwin)
	NCPUS=$(( $(sysctl -n hw.ncpu) + 1 ))
	if ! [ -f lib/mac64/libradio.a ]; then
		rm -f CMakeCache.txt
		cmake . -DOPENGPWS="$OPENGPWS" -DLIBACFUTILS_SRC="$LIBACFUTILS_SRC" -DLIBACFUTILS_REDIST="$LIBACFUTILS_REDIST" \
		    $CMAKE_OPTS
		cmake --build . --parallel "$NCPUS"
	fi
	;;
Linux)
	NCPUS=$(( $(grep 'processor[[:space:]]\+:' /proc/cpuinfo  | wc -l) + \
	    1 ))
	if ! [ -f lib/lin64/libradio.a ]; then
		rm -f CMakeCache.txt
		cmake . -DOPENGPWS="$OPENGPWS" -DLIBACFUTILS_SRC="$LIBACFUTILS_SRC" -DLIBACFUTILS_REDIST="$LIBACFUTILS_REDIST" \
		    $CMAKE_OPTS
		cmake --build . --parallel "$NCPUS"
	fi
	if ! [ -f libradio.plugin/mingw64/libradio.plugin.xpl ]; then
		rm -f CMakeCache.txt
		cmake . -DOPENGPWS="$OPENGPWS" -DLIBACFUTILS_SRC="$LIBACFUTILS_SRC" -DLIBACFUTILS_REDIST="$LIBACFUTILS_REDIST" \
		    -DCMAKE_TOOLCHAIN_FILE=XCompile.cmake \
		    -DHOST=x86_64-w64-mingw32 \
		    $CMAKE_OPTS
		cmake --build . --parallel "$NCPUS"
	fi
	;;
*)
	echo "Unsupported build platform" >&2
	exit 1
	;;
esac
