#!/bin/sh
#-------------------------------------------------------------------------------
# Copyright (C) 2022, CREATIS
# Centre de Recherche en Acquisition et Traitement de l'Image pour la Santé
# CNRS UMR 5220 - INSERM U1294 - Université Lyon 1 - INSA Lyon Université 
# Jean Monnet Saint-Etienne
# FRANCE
#
# All rights reserved.
#
# The utilisation of this source code is governed by a CeCILL licence which can
# be found in the LICENCE.txt file.
#-------------------------------------------------------------------------------

set -e; set -o xtrace

cmake_dir="$TARGET_TEMP_DIR/CMake"
install_dir="$TARGET_TEMP_DIR/Install"

[ -d "$install_dir" ] && [ ! -f "$install_dir/.incomplete" ] && exit 0

mkdir -p "$install_dir"
touch "$install_dir/.incomplete"

args=()
export MAKEFLAGS="-j $(sysctl -n hw.ncpu)"

cd "$cmake_dir"
#make "${args[@]}" ITKIOImageBase ITKStatistics ITKTransform
make "${args[@]}" install

# wrap the libs into one
mkdir -p "$install_dir/wlib"
ars=$(find "$install_dir/lib" -name '*.a' -type f)
libtool -static -o "$install_dir/wlib/lib$PRODUCT_NAME.a" $ars

rm -f "$install_dir/.incomplete"

exit 0
