#!/bin/bash
#-------------------------------------------------------------------------------
# Name        : xcode-archive-post.sh
# Description : Build release package.
# Authors     : Alessandro Volz  <aglv@me.com>
# 
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

if [ -z "$XCODE_VERSION_ACTUAL" ]; then
    echo "error: this script must be executed from Xcode"
    exit 1
fi

exec > "$HOME/Library/Logs/Xcode-$PROJECT_NAME-Archive-Post.log" 2>&1
env
set -o xtrace

# archive version and icon

cd "$PROJECT_DIR"
desc=$(git describe --tags --always --dirty)

current_project_version="$CURRENT_PROJECT_VERSION"
if [ -z "$current_project_version" ]; then
    current_project_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFOPLIST_FILE")
fi

/usr/libexec/PlistBuddy -c "Add :ApplicationProperties dict" \
    -c "Add :ApplicationProperties:ApplicationPath string '${INSTALL_PATH:1}/$FULL_PRODUCT_NAME'" \
    -c "Add :ApplicationProperties:CFBundleIdentifier string '$PRODUCT_BUNDLE_IDENTIFIER'" \
    -c "Add :ApplicationProperties:CFBundleShortVersionString string '$current_project_version'" \
    -c "Add :ApplicationProperties:CFBundleVersion string '$desc'" \
    -c "Add :ApplicationProperties:IconPaths array" \
    -c "Add :ApplicationProperties:IconPaths:0 string '${INSTALL_PATH:1}/$FULL_PRODUCT_NAME/Contents/Resources/CMRSegToolsIcon.png'" \
    "$ARCHIVE_PATH/Info.plist"

archives_path=$(dirname "$ARCHIVE_PATH")
while [ $(basename "$archives_path") != 'Archives' ]; do
    archives_path=$(dirname "$archives_path")
done

tag="$desc"; for (( i=0; ; i++ )); do
    [ "$i" -ne '0' ] && tag="$desc-$i"
    archive_path="$archives_path/$PRODUCT_NAME-$tag.xcarchive"
    [ ! -e "$archive_path" ] && break
done

if [ "$archive_path" != "$ARCHIVE_PATH" ]; then
    mv "$ARCHIVE_PATH" "$archive_path"
    rmdir "$(dirname "$ARCHIVE_PATH")"
    archive_products_path="$archive_path/$(basename "$ARCHIVE_PRODUCTS_PATH")"
else
    archive_products_path="$ARCHIVE_PRODUCTS_PATH"
fi

# zip the built plugin

product_path="$archive_products_path/$INSTALL_PATH/$FULL_PRODUCT_NAME"

zips_path="$archive_path/ZIPs"
mkdir -p "$zips_path"

zip_path="$zips_path/$PRODUCT_NAME-$current_project_version.zip"

echo "Zipping $product_path to $zip_path"

rm -Rf "$zip_path"

cd "$(dirname "$product_path")"
find "$(basename "$product_path")" -path '*/.*' -prune -o -print | zip --symlinks "$zip_path" -@

# show results

open -R "$zip_path"
( sleep 2 ; open "$archive_path" ) & # open to select in organizer

exit 0

# zip the code for this project and, if git-archive-all is available, all submodules

zip_path="$zips_path/$PRODUCT_NAME-$current_project_version-Code.zip"

echo "Zipping code to $zip_path"

command_exists () {
    type "$1" >/dev/null 2>&1 ;
}

cd "$PROJECT_DIR"
if command_exists git-archive-all ; then
    git-archive-all "$zip_path"
else
    git archive --format zip --output "$zip_path" master
    if [ -e ".gitmodules" ] && [ $(grep path .gitmodules -c) != "0" ] ; then
        echo "warning: I need git-archive-all to produce a project code archive complete with all submodules. The currently produced archive only contains the code for $PROJECT_NAME, not its submodules!"
    fi
fi

exit 0
