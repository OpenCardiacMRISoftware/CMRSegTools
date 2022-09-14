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

#args+=(-DVTK_USE_OFFSCREEN_EGL:BOOL=OFF)
args+=(-DVTK_USE_X:BOOL=OFF)
args+=(-DVTK_USE_COCOA:BOOL=OFF)
#args+=(-DVTK_USE_64BITS_IDS=ON)
args+=(-DBUILD_DOCUMENTATION=OFF)
args+=(-DBUILD_EXAMPLES=OFF)
args+=(-DBUILD_SHARED_LIBS=OFF)
args+=(-DBUILD_TESTING=OFF)
args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET")
args+=(-DCMAKE_OSX_ARCHITECTURES="$ARCHS")

args+=(-DVTK_USE_SYSTEM_ZLIB:BOOL=ON)
args+=(-DVTK_USE_SYSTEM_EXPAT=ON)
args+=(-DVTK_USE_SYSTEM_LIBXML2=ON)

# args+=(-DCMAKE_VERBOSE_MAKEFILE:BOOL=ON)

[ "$CONFIGURATION" == 'Release' ] && args+=( -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE=-Ofast )
[ "$CONFIGURATION" != 'Release' ] && args+=( -DCMAKE_BUILD_TYPE=Debug )

args+=(-DVTK_Group_StandAlone=OFF -DVTK_Group_Rendering=OFF) # disable the default groups
args+=(-DModule_vtkIOImage=ON)
args+=(-DModule_vtkFiltersGeneral=ON)
args+=(-DModule_vtkImagingStencil=ON)

args+=(-DCMAKE_INSTALL_PREFIX="$install_dir")
args+=(-DVTK_INSTALL_INCLUDE_DIR="include")

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

cd "$cmake_dir"
cmake "${args[@]}"

echo "$hash" > "$cmake_dir/.cmakehash"

exit 0
