// swift-tools-version: 6.0
// Package.swift — tvheadend-ios-lib
// Replaces CocoaPods / AFNetworking with a native SPM manifest.
// Build: swift build (in this directory)
// Xcode: Add local package via File → Add Package Dependencies

import PackageDescription

let package = Package(
    name: "tvheadend-ios-lib",
    platforms: [
        .tvOS(.v18),
    ],
    products: [
        .library(
            name: "tvhclient-lib",
            targets: ["tvhclient-lib"]
        ),
    ],
    targets: [
        .target(
            name: "tvhclient-lib",
            // Sources live in tvheadend-ios-lib/tvheadend-ios-lib/ relative to Package.swift.
            path: "tvheadend-ios-lib",
            // All .h files in the sources directory are public headers.
            publicHeadersPath: ".",
            cSettings: [
                // Mirror the PCH's #define DEVICE_IS_TVOS so all #ifdef / #ifndef guards resolve correctly.
                .define("DEVICE_IS_TVOS"),
                // ENABLE_XBMC and ENABLE_EXTERNAL_APPS are iOS-only features — omitted for tvOS.
                // Re-add here if XBMC integration is needed in a future story.
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CFNetwork"),
                // CoreText and MediaAccessibility: were weak-linked in podspec for iOS 8/tvOS 9 legacy.
                // Since tvOS 18 is guaranteed, regular linking is safe.
                .linkedFramework("CoreText"),
                .linkedFramework("MediaAccessibility"),
            ]
        ),
    ]
)
