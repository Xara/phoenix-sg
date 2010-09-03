#!/bin/bash
START_DIR=$(cd $(dirname "$0"); pwd)
INDRA_DIR=$START_DIR/indra
OUTPUT_DIR=$START_DIR/builds
DEPENDENCY_DIR=$START_DIR/dependencies

if [ $1 = "release" ]; then
        echo "Building for release."
        BUILD_RELEASE="yes"
else
        echo "Building beta."
        BUILD_RELEASE=""
fi

if [ -z "$2" ]; then
	echo "Usage: $0 <release|beta> buildnumber"
	exit 1
else
	REVISION=$2
fi

configure()
{
        echo "Configuring (for real)..."
        ./develop.py configure -G Xcode -DCMAKE_OSX_ARCHITECTURES="$1" -DOPENAL:BOOL=FALSE -DFMOD:BOOL=TRUE -DCMAKE_BUILD_TYPE=Release -DGCC_DISABLE_FATAL_WARNINGS:BOOL=TRUE \
        -DCMAKE_C_FLAGS:STRING="$2" -DCMAKE_CXX_FLAGS:STRING="$2" > /dev/null
}

set_channel()
{
        if [ -z "$BUILD_RELEASE" ]; then
                sed -e s/Internal/Beta/ -i '' llcommon/llversionviewer.h
        else
                sed -e s/Internal/Release/ -i '' llcommon/llversionviewer.h
        fi

        sed -e "s/LL_VERSION_BUILD = 0/LL_VERSION_BUILD = $REVISION/" -i '' llcommon/llversionviewer.h
}

build()
{
        echo "Building..."
        xcodebuild -target ALL_BUILD -configuration Release GCC_VERSION=4.0 > /dev/null
}

copy_resources()
{
        echo "Copying resources..."

        cp -R $DEPENDENCY_DIR/cursors_mac Phoenix\ Viewer.app/Contents/Resources/

        if [ -n "$BUILD_RELEASE" ]; then
                SETTINGS_FILE='settings_phoenix.xml'
        else
                SETTINGS_FILE='settings_phoenixviewerbeta.xml'
        fi
        echo "--settings $SETTINGS_FILE" > Phoenix\ Viewer.app/Contents/Resources/arguments.txt
}

# Sends output file to stdout
make_disk_image()
{
        if [ -n "$BUILD_RELEASE" ]; then
                IMAGE="release-template.dmg"
                VOLUME_NAME="Phoenix Viewer $REVISION"
                OUTPUT_FILE="Phoenix_Viewer_1.5.0.${REVISION}_${1}.dmg"
        else
                IMAGE="beta-template.dmg"
                VOLUME_NAME="Phoenix Viewer $REVISION Beta"
                OUTPUT_FILE="Phoenix_Viewer_1.5.0.${REVISION}_${1}_Beta.dmg"
        fi

        # hdiutil convert won't overwrite an existing output file
        rm -f "$OUTPUT_DIR/$OUTPUT_FILE"

        # We store the templates as compressed images, so decompress it now.
        hdiutil convert "$DEPENDENCY_DIR/$IMAGE" -format UDRW -o temp-image.dmg > /dev/null
        hdiutil attach -mountpoint "$DEPENDENCY_DIR/build-image" -nobrowse temp-image.dmg > /dev/null

        # diskutil requires the full mount path.
        diskutil renameVolume "$DEPENDENCY_DIR/build-image" "$VOLUME_NAME" > /dev/null

        # Copy the viewer in
        cp -R Phoenix\ Viewer*.app "$DEPENDENCY_DIR/build-image/" > /dev/null

        # Compress/store the image and dispose of the temporary one.
        hdiutil detach "$DEPENDENCY_DIR/build-image" > /dev/null
        hdiutil convert temp-image.dmg -format UDBZ -o "$OUTPUT_DIR/$OUTPUT_FILE" > /dev/null
        rm temp-image.dmg
        echo "$OUTPUT_DIR/$OUTPUT_FILE";
}

# Sends output file to stdout
make_package()
{
        if [ -z "$BUILD_RELEASE" ]; then
                mv Phoenix\ Viewer.app Phoenix\ Viewer\ Beta.app
        fi
        echo $(make_disk_image $1)
}

upload()
{
#        echo "Uploading..."
#		#Be sure to take the upload function out before pushing any changes as it contains server credentials and hidden URLs.
        echo "The final package can be found at $1."
}

#This function needs to be changed to hg, also we're not longer using a /linden folder... -phox
#cd "$START_DIR/linden"
#if [ -z $1 ]; then
#        svn up
#else
#        svn up -r$1
#fi
#
#if [ $? -ne 0 ]; then
#        echo "Couldn't update from subversion."
#        exit 1
#fi
#
#REAL_REVISION=0
#while read line; do
#        substring=${line:0:10}
#        if [[ $substring == "Revision: " ]]; then
#                REAL_REVISION=${line:10:4}
#        fi
#done < <(svn info)
#if [ $REAL_REVISION -eq 0 ]; then
#        echo "Could not determine svn revision."
#        exit 2
#fi
#
#if [ -z $REVISION ]; then
#        REVISION=$REAL_REVISION
#fi

echo "Preparing..."
rm installed.xml 2>/dev/null

#echo "Building revision $REVISION."
echo "Building..."
cd indra

if [ -z $SKIP_INTEL ]; then
        echo "------------------------------------------"
        echo "                 x86 Build                "
        echo "------------------------------------------"
        echo "Cleaning..."
        cd $INDRA_DIR
        ./develop.py clean > /dev/null

        configure i386 "-O2 -fomit-frame-pointer -frename-registers -ftree-vectorize -fweb -fexpensive-optimizations -march=i686 \
                                -msse -mfpmath=sse -msse2 -pipe -DLL_VECTORIZE=1 -DLL_SSE=1 -DLL_SSE2=1"

        cd build-darwin-i386
        set_channel
        build
        BUILD_SUCCESS=$?
        if [ $BUILD_SUCCESS -eq 0 ]; then
                cd newview/Release
                copy_resources

                echo "Liposuction..."
                lipo -thin i386 Phoenix\ Viewer.app/Contents/MacOS/libhunspell-1.2.dylib -output Phoenix\ Viewer.app/Contents/MacOS/libhunspell-1.2.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/MacOS/libndofdev.dylib -output Phoenix\ Viewer.app/Contents/MacOS/libndofdev.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/MacOS/libotr.dylib -output Phoenix\ Viewer.app/Contents/MacOS/libotr.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/MacOS/7za -output Phoenix\ Viewer.app/Contents/MacOS/7za

                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/SLVoice -output Phoenix\ Viewer.app/Contents/Resources/SLVoice
                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/libalut.dylib -output Phoenix\ Viewer.app/Contents/Resources/libalut.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/libopenal.dylib -output Phoenix\ Viewer.app/Contents/Resources/libopenal.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/libortp.dylib -output Phoenix\ Viewer.app/Contents/Resources/libortp.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/libvivoxsdk.dylib -output Phoenix\ Viewer.app/Contents/Resources/libvivoxsdk.dylib
                lipo -thin i386 Phoenix\ Viewer.app/Contents/Resources/llplugin/libllqtwebkit.dylib -output Phoenix\ Viewer.app/Contents/Resources/llplugin/libllqtwebkit.dylib

                echo "Packaging..."
                RESULT="$(make_package Intel)"
                upload "$RESULT"
                echo "Done Intel."
        else
                echo "Intel build failed :<"
        fi
else
        echo "Skipped intel build."
fi

# Some cleanup.
rm installed.xml 2>/dev/null
echo "Finished."
