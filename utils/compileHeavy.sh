#!/bin/sh

usage ()
{
	echo ""
	echo "Required arguments:"
	echo " -p : Patch name"
	echo " -t : Target to compile. Available options = IOS, OSX, ALL"
	echo ""
	echo "Additional optional arguments"
	echo " -q : 1 = Quit Unity before compiling"
	echo " -o : 1 = Open Unity after compiling"
	echo ""
	echo "Script assumes you are currently in directory of the Pd patch"
	echo "Example usage:"
	echo " $ hvcompile -p myPatch -t OSX -q 1 -o 1"
	exit 1
}

if [[ $# -eq 0 ]]
	then
    	echo "Not enough arguments supplied"
		usage
fi

PATCH_NAME=""
DEST_FOLDER=""
PLUGIN_FOLDER=""
UNITYPLUGIN_PATH=""
OPEN_UNITY=0
QUIT_UNITY=0
COMPILE_OSX=0
COMPILE_IOS=0
TARGET_PRESENT=0

while getopts ":p:v:f:u:o:q:t:" opt; do
	case "$opt" in
		p)
			# we found a patch name
			echo "Patch name : $OPTARG"
			PATCH_NAME="$OPTARG"
			;;
		o)
			# we found a patch name
			echo "Will Open Unity"
			OPEN_UNITY=1
			;;
		q)
			# we found a patch name
			echo "Will Quit Unity"
			QUIT_UNITY=1
			;;
        t) 
			multi+=("$OPTARG")
			;;
	esac
done

shift $((OPTIND -1))

for val in "${multi[@]}"; do
    echo " - $val"
    if [[ $val == IOS ]]
	then
		echo "Will Compile iOS"
		COMPILE_IOS=1
		TARGET_PRESENT=1
	elif [[ $val == OSX ]]
	then
		echo "Will Compile OSX"
		COMPILE_OSX=1
		TARGET_PRESENT=1
	elif [[ $val == ALL ]]
	then
		echo "Will Compile all targets"
		COMPILE_OSX=1
		COMPILE_IOS=1
		TARGET_PRESENT=1
	else
		echo "Unrecognised target option given. Valid options include IOS, OSX, or ALL for both"
	fi
done

if [[ $TARGET_PRESENT == 0 ]]
then
	echo "No target selected. Valid options include IOS, OSX, or ALL for both"
	usage
fi

XCODEPROJ="Hv_"$PATCH_NAME"_Unity.xcodeproj"
MACTARGET="Hv_"$PATCH_NAME"_AudioLib"
IOSTARGET="Hv_"$PATCH_NAME"_AudioLib_iOS"
MACLIB="Hv_"$PATCH_NAME"_AudioLib.bundle"
IOSLIB="libHv_"$PATCH_NAME"_AudioLib.a"
WRAPPER="Hv_"$PATCH_NAME"_AudioLib.cs"

if [[ $QUIT_UNITY == 1 ]]
then
	echo "Quitting Unity..."
	osascript -e 'quit app "/Applications/Unity/Hub/Editor/2018.2.2f1/Unity.app"'
fi

echo "Removing previous assets..."
rm -f -r ./hv-out
XCODE_COMMAND="sudo xcodebuild -project ./hv-out/unity/xcode/$XCODEPROJ"
if [[ $COMPILE_OSX == 1 ]]
then
	XCODE_COMMAND=$XCODE_COMMAND" -target "$MACTARGET
	rm -r -f ../../Unity/Assets/Plugins/OSX/$MACLIB
fi
if [[ $COMPILE_IOS == 1 ]]
then
	XCODE_COMMAND=$XCODE_COMMAND" -target "$IOSTARGET
	rm -f ../../Unity/Assets/Plugins/iOS/$IOSLIB
fi
XCODE_COMMAND=$XCODE_COMMAND" -quiet"

echo "Compiling patch..."
python ~/workspace/enzienaudio/hvcc/hvcc.py ./_main.pd -g unity -o hv-out/ -n $PATCH_NAME 

echo "Building Xcode project..."
$XCODE_COMMAND

echo "Moving targets into place..."
if [[ $COMPILE_OSX == 1 ]]
then
	sudo chmod -R 777 hv-out/unity/build/macos/x86_64/Release/$MACLIB
	sudo mv -f hv-out/unity/build/macos/x86_64/Release/$MACLIB ../../Unity/Assets/Plugins/OSX/$MACLIB
fi
if [[ $COMPILE_IOS == 1 ]]
then
	sudo chmod -R 777 ./hv-out/unity/build/ios/armv7\ arm64/Release/libHv_gladly_AudioLib.a
	sudo mv -f ./hv-out/unity/build/ios/armv7\ arm64/Release/libHv_gladly_AudioLib.a ../../Unity/Assets/Plugins/iOS/$IOSLIB
fi

echo "Moving wrapper into place..."
sudo mv -f ./hv-out/unity/build/macos/x86_64/Release/$WRAPPER ../../Unity/Assets/Plugins/$WRAPPER

if [[ $OPEN_UNITY == 1 ]]
then
	echo "Opening Unity..."
	"/Applications/Unity/Hub/Editor/2018.2.2f1/Unity.app/Contents/MacOS/Unity" -projectPath ../../Unity/ &
fi