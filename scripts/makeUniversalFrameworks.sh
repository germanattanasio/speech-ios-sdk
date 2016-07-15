#! /bin/bash

set -e

# The following conditionals come from
# https://github.com/kstenerud/iOS-Universal-Framework

if [[ "$SDK_NAME" =~ ([A-Za-z]+) ]]
then
    SF_SDK_PLATFORM=${BASH_REMATCH[1]}
else
    echo "Could not find platform name from SDK_NAME: $SDK_NAME"
    exit 1
fi

if [[ "$SDK_NAME" =~ ([0-9]+.*$) ]]
then
    SF_SDK_VERSION=${BASH_REMATCH[1]}
else
    echo "Could not find sdk version from SDK_NAME: $SDK_NAME"
    exit 1
fi

if [[ "$SF_SDK_PLATFORM" = "iphoneos" ]]
then
    SF_OTHER_PLATFORM=iphonesimulator
else
    SF_OTHER_PLATFORM=iphoneos
fi

if [[ "$BUILT_PRODUCTS_DIR" =~ (.*)$SF_SDK_PLATFORM$ ]]
then
    SF_OTHER_BUILT_PRODUCTS_DIR="${BASH_REMATCH[1]}${SF_OTHER_PLATFORM}"
else
    echo "Could not find platform name from build products directory: $BUILT_PRODUCTS_DIR"
    exit 1
fi

# Create directory for universal builds
UNIVERSAL_BUILD_PRODUCTS_DIR=$(dirname "${BUILT_PRODUCTS_DIR}")"/${CONFIGURATION}-universal/"
mkdir -p "${UNIVERSAL_BUILD_PRODUCTS_DIR}"

# Build the other platform
xcodebuild -project "${PROJECT_FILE_PATH}" \
    -target "${TARGET_NAME}" \
    -configuration "${CONFIGURATION}" \
    -sdk ${SF_OTHER_PLATFORM}${SF_SDK_VERSION} \
    BUILD_DIR="${BUILD_DIR}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" $ACTION

# Universal Dynamic framework
# ===========================

# Replicate what Xcode defines
SF_EXECUTABLE_NAME="WatsonSDK"
SF_WRAPPER_NAME="WatsonSDK.framework"
SF_EXECUTABLE_PATH="${SF_WRAPPER_NAME}/${SF_EXECUTABLE_NAME}"

# Copy iphoneos platform into the universal directory (must be iphoneos so Info.plist is correct)
IPHONEOS_BUILD_PRODUCTS_DIR=$(dirname "${BUILT_PRODUCTS_DIR}")"/${CONFIGURATION}-iphoneos/"
rm -rf "${UNIVERSAL_BUILD_PRODUCTS_DIR}/${SF_WRAPPER_NAME}"
cp -R "${IPHONEOS_BUILD_PRODUCTS_DIR}/${SF_WRAPPER_NAME}" "${UNIVERSAL_BUILD_PRODUCTS_DIR}/${SF_WRAPPER_NAME}"

# Make the framework universal
lipo -create "${BUILT_PRODUCTS_DIR}/${SF_EXECUTABLE_PATH}" "${SF_OTHER_BUILT_PRODUCTS_DIR}/${SF_EXECUTABLE_PATH}" \
    -output "${UNIVERSAL_BUILD_PRODUCTS_DIR}/${SF_EXECUTABLE_PATH}"

# Create a zip of the framework and add it to the project root
cd "${UNIVERSAL_BUILD_PRODUCTS_DIR}"
zip -r "${SRCROOT}/${SF_WRAPPER_NAME}.zip" "${SF_WRAPPER_NAME}"

# Universal Static library
# ========================

SF_LIB_EXECUTABLE_PATH="libwatsonsdk.a"

# Make static library universal
xcodebuild -project "${PROJECT_FILE_PATH}" \
    -target "${TARGET_NAME}" \
    -configuration "${CONFIGURATION}" \
    -sdk ${SF_OTHER_PLATFORM}${SF_SDK_VERSION} \
    BUILD_DIR="${BUILD_DIR}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" $ACTION


# Build the other platform
lipo -create "${BUILT_PRODUCTS_DIR}/${SF_LIB_EXECUTABLE_PATH}" "${SF_OTHER_BUILT_PRODUCTS_DIR}/${SF_LIB_EXECUTABLE_PATH}" \
    -output "${UNIVERSAL_BUILD_PRODUCTS_DIR}/${SF_LIB_EXECUTABLE_PATH}"

# Copy headers
rm -rf "${UNIVERSAL_BUILD_PRODUCTS_DIR}/watsonsdkHeaders"
cp -R "${BUILT_PRODUCTS_DIR}/watsonsdkHeaders" "${UNIVERSAL_BUILD_PRODUCTS_DIR}/watsonsdkHeaders"

# Universal Static Framework (framework for old iOS6)
# ===================================================

# Build a simple (non versioned) static framework
# watsonsdk.framework/
# ├── Headers/
# ├── Resources/
# ├── Info.plist
# └── watsonsdk
STATIC_FRAMEWORK="${UNIVERSAL_BUILD_PRODUCTS_DIR}/staticFramework/watsonsdk.framework"
rm -rf ${STATIC_FRAMEWORK}
mkdir -p ${STATIC_FRAMEWORK}
mkdir -p "${STATIC_FRAMEWORK}/Headers"
mkdir -p "${STATIC_FRAMEWORK}/Resources"
cp "${UNIVERSAL_BUILD_PRODUCTS_DIR}/${SF_LIB_EXECUTABLE_PATH}" "${STATIC_FRAMEWORK}/watsonsdk"
cp -R "${UNIVERSAL_BUILD_PRODUCTS_DIR}/WatsonSDK.framework/Headers" "${STATIC_FRAMEWORK}"
cp "${UNIVERSAL_BUILD_PRODUCTS_DIR}/WatsonSDK.framework/Info.plist" "${STATIC_FRAMEWORK}"

# Success!

if [ $1 == "--open" ]
then
    open "${UNIVERSAL_BUILD_PRODUCTS_DIR}"
fi
