// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PomodoroClock",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(
            name: "PomodoroClock",
            targets: ["PomodoroClock"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "PomodoroClock",
            path: "Sources/PomodoroClock",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/PomodoroClock/Resources/Info.plist",
                ]),
            ]
        ),
    ]
)
