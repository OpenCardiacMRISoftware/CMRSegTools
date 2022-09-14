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

path="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd )/$(basename "${BASH_SOURCE[0]}")"
cd "$TARGET_NAME"; pwd

env=$(env|sort|grep -v 'LLBUILD_BUILD_ID=\|LLBUILD_LANE_ID=\|LLBUILD_TASK_ID=\|Apple_PubSub_Socket_Render=\|DISPLAY=\|SHLVL=\|SSH_AUTH_SOCK=\|SECURITYSESSIONID=\|COMMAND_MODE=')
hash="$(git describe --always --tags --dirty) $(md5 -q "$path")-$(md5 -qs "$env")"

set -e ; set -x

source_dir="$PROJECT_DIR/$TARGET_NAME"
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
mkdir -p "$cmake_dir"

echo "$hash" > "$cmake_dir/.cmakehash"
set +x ; echo "$env" > "$cmake_dir/.cmakeenv" ; set -x

args=("$source_dir" -Wno-dev)
cfs=(-w -Wno-logical-not-parentheses)
cxxfs=(-w) # Wno-mismatched-tags -Wno-macro-redefined -Wno-unused-const-variable -Wno-unused-variable -Wno-unused-function -Wno-overloaded-virtual -Wno-unused-private-field -Wno-tautological-pointer-compare -Wno-pessimizing-move -Wno-logical-not-parentheses

args+=(-DDCMTK_WITH_DOXYGEN=OFF)
args+=(-DDCMTK_USE_CXX11_STL=ON)
args+=(-DBUILD_SHARED_LIBS=OFF)
args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
args+=(-DCMAKE_OSX_ARCHITECTURES="$ARCHS")

args+=(-DCMAKE_INSTALL_PREFIX="$install_dir")

if [ ! -z "$CLANG_CXX_LIBRARY" ] && [ "$CLANG_CXX_LIBRARY" != 'compiler-default' ]; then
#    args+=(-DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LIBRARY="$CLANG_CXX_LIBRARY")
    cxxfs+=(-stdlib="$CLANG_CXX_LIBRARY")
fi

if [ ! -z "$CLANG_CXX_LANGUAGE_STANDARD" ]; then
#    args+=(-DCMAKE_XCODE_ATTRIBUTE_CLANG_CXX_LANGUAGE_STANDARD="$CLANG_CXX_LANGUAGE_STANDARD")
#    cxxfs+=(-std="$CLANG_CXX_LANGUAGE_STANDARD")
    args+=(-DDCMTK_CXX11_FLAGS="-std=$CLANG_CXX_LANGUAGE_STANDARD")
else
    args+=(-DDCMTK_CXX11_FLAGS="-std=c++0x") # or c++14
fi

args+=(-DDCMTK_WITH_SNDFILE=OFF)
args+=(-DDCMTK_WITH_ICU=OFF)


args+=(-DCMAKE_C_FLAGS="-Wno-logical-not-parentheses")

if [ ${#cfs[@]} -ne 0 ]; then
    cfss="${cfs[@]}"
    args+=(-DCMAKE_C_FLAGS="$cfss")
fi
if [ ${#cxxfs[@]} -ne 0 ]; then
    cxxfss="${cxxfs[@]}"
    args+=(-DCMAKE_CXX_FLAGS="$cxxfss")
fi

cd "$cmake_dir"
cmake "${args[@]}"

echo "$hash" > "$cmake_dir/.cmakehash"
