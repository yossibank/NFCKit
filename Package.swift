// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NFCKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MyNumberCardReader",
            type: .dynamic,
            targets: ["MyNumberCardReader"]
        )
    ],
    targets: [
        .target(name: "NFCCore"),
        .target(
            name: "NFCTransport",
            dependencies: ["NFCCore"]
        ),
        .target(
            name: "NFCTransportMocks",
            dependencies: ["NFCTransport"]
        ),
        .target(
            name: "MyNumberCardReader",
            dependencies: [
                "NFCCore",
                "NFCTransport"
            ]
        ),
        .testTarget(
            name: "NFCCoreTests",
            dependencies: [
                "NFCCore",
                "NFCTransportMocks"
            ]
        ),
        .testTarget(
            name: "NFCTransportTests",
            dependencies: [
                "NFCCore",
                "NFCTransport",
                "NFCTransportMocks"
            ]
        ),
        .testTarget(
            name: "MyNumberCardReaderTests",
            dependencies: [
                "NFCCore",
                "NFCTransport",
                "NFCTransportMocks",
                "MyNumberCardReader"
            ]
        )
    ]
)
