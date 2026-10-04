#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
rm -rf build

frameworks=()

for platform sdk in "iOS" "iphoneos" "iOS Simulator" "iphonesimulator"; do
    xcodebuild archive \
        -quiet \
        -scheme NFCKit \
        -destination "generic/platform=$platform" \
        -archivePath "build/$sdk.xcarchive" \
        -derivedDataPath "build/DerivedData-$sdk" \
        SKIP_INSTALL=NO \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES

    framework="build/$sdk.xcarchive/Products/usr/local/lib/MyNumberCardReader.framework"
    module="build/DerivedData-$sdk/Build/Intermediates.noindex/ArchiveIntermediates/NFCKit/BuildProductsPath/Release-$sdk/MyNumberCardReader.swiftmodule"

    mkdir -p "$framework/Modules/MyNumberCardReader.swiftmodule"

    for file in "$module"/*.swiftinterface "$module"/*.swiftdoc "$module"/*.abi.json; do
        [[ $file == *.package.swiftinterface || $file == *.private.swiftinterface ]] && continue
        cp "$file" "$framework/Modules/MyNumberCardReader.swiftmodule/"
    done

    frameworks+=(-framework "$framework")
done

xcodebuild -create-xcframework "${frameworks[@]}" -output build/MyNumberCardReader.xcframework

(cd build && ditto -c -k --sequesterRsrc --keepParent MyNumberCardReader.xcframework MyNumberCardReader.xcframework.zip)
swift package compute-checksum build/MyNumberCardReader.xcframework.zip
