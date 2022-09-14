#!/bin/sh
#-------------------------------------------------------------------------------
# Copyright (C) 2022, CREATIS
# Centre de Recherche en Acquisition et Traitement de l'Image pour la Santé
# CNRS UMR 5220 - INSERM U1294 - Université Lyon 1 - INSA Lyon - 
# Université Jean Monnet Saint-Etienne
# FRANCE 
#
# All rights reserved.
#
# The utilisation of this source code is governed by a CeCILL licence which can
# be found in the LICENCE.txt file.
#-------------------------------------------------------------------------------
# ******************************************************************************
# To avoid excess CMake calls (because these take a long time to execute), this 
# script stores the current git description and md5 hash of the repository CMake 
# directory; when available, it compares the stored values to the current values 
# and exits if nothing has changed.
# ******************************************************************************

path="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )/$(basename "${BASH_SOURCE[0]}")"
cd "$TARGET_NAME"; pwd

env=$(env|sort|grep -v 'LLBUILD_BUILD_ID=\|LLBUILD_LANE_ID=\|LLBUILD_TASK_ID=\|Apple_PubSub_Socket_Render=\|DISPLAY=\|SHLVL=\|SSH_AUTH_SOCK=\|SECURITYSESSIONID=\|COMMAND_MODE=')
hash="$(git describe --always --tags --dirty) $(md5 -q "$path")-$(md5 -qs "$env")"

set -e ; set -x

cmake_dir="$TARGET_TEMP_DIR/CMake"
install_dir="$TARGET_TEMP_DIR/Install"

mkdir -p "$cmake_dir"; cd "$cmake_dir"
[ -e Makefile -a -f .cmakehash ] && [ "$(cat '.cmakehash')" = "$hash" ] && exit 0

set +x ; echo "$env" > "$cmake_dir/.cmakeenv.now" ; set -x
[ -f "$cmake_dir/.cmakeenv" ] && set +e && diff "$cmake_dir/.cmakeenv" "$cmake_dir/.cmakeenv.now" && set -e

command -v cmake >/dev/null 2>&1 || { echo >&2 "error: building $TARGET_NAME requires CMake. Please install CMake. Aborting."; exit 1; }
command -v pkg-config >/dev/null 2>&1 || { echo >&2 "error: building $TARGET_NAME requires pkg-config. Please install pkg-config. Aborting."; exit 1; }

mv "$cmake_dir" "$cmake_dir.tmp"
[ -d "$install_dir" ] && mv "$install_dir" "$install_dir.tmp"
rm -Rf "$cmake_dir.tmp" "$install_dir.tmp"
mkdir -p "$cmake_dir"; cd "$cmake_dir"

set +x ; echo "$env" > "$cmake_dir/.cmakeenv" ; set -x

args=("$PROJECT_DIR/$TARGET_NAME")
cxxfs=( -w -fvisibility=default )

#args+=(-DNO_CMAKE_SYSTEM_PATH=ON)

args+=(-DITK_USE_64BITS_IDS=ON)
args+=(-DBUILD_DOCUMENTATION=OFF)
args+=(-DBUILD_EXAMPLES=OFF)
args+=(-DBUILD_SHARED_LIBS=OFF)
args+=(-DBUILD_TESTING=OFF)
args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
args+=(-DCMAKE_OSX_ARCHITECTURES="$ARCHS")

args+=(-DITK_BUILD_DEFAULT_MODULES=OFF)
args+=(-DModule_ITKIOImageBase=ON)
args+=(-DModule_ITKStatistics=ON)
args+=(-DModule_ITKTransform=ON)
args+=(-DModule_ITKReview=ON)

args+=(-DCMAKE_INSTALL_PREFIX="$install_dir")
args+=(-DITK_INSTALL_INCLUDE_DIR="include")

if [ ! -z "$CLANG_CXX_LIBRARY" ] && [ "$CLANG_CXX_LIBRARY" != 'compiler-default' ]; then
    cxxfs+=(-stdlib="$CLANG_CXX_LIBRARY")
fi

if [ ! -z "$CLANG_CXX_LANGUAGE_STANDARD" ]; then
    cxxfs+=(-std="$CLANG_CXX_LANGUAGE_STANDARD")
fi

if [ ${#cxxfs[@]} -ne 0 ]; then
    cxxfss="${cxxfs[@]}"
    args+=(-DCMAKE_CXX_FLAGS="$cxxfss")
fi

cmake "${args[@]}"

echo "$hash" > "$cmake_dir/.cmakehash"

exit 0
