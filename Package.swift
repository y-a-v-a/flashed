// swift-tools-version: 5.9
//
// Development-only SwiftPM overlay for fast `swift test` iteration on Core/.
// This is NOT the "extract Core as a package" migration from TASKS 0.7 —
// no files are moved, no Core-Package/ directory exists. This manifest
// simply points SwiftPM at the real on-disk paths from LAYOUT.md so Core
// can be built and tested without an Xcode project.
//
// When/if TASKS 0.7 is triggered (Xcode test turnaround > 10s), this file
// will be replaced by a real package at Core-Package/ and MorseBeacon/Core/
// will be removed per LAYOUT.md.

import PackageDescription

let package = Package(
  name: "MorseBeaconCore",
  platforms: [.macOS(.v13), .iOS(.v17)],
  products: [
    .library(name: "Core", targets: ["Core"]),
    .library(name: "Runtime", targets: ["Runtime"]),
  ],
  targets: [
    .target(
      name: "Core",
      path: "MorseBeacon/Core"
    ),
    .target(
      name: "Runtime",
      dependencies: ["Core"],
      path: "MorseBeacon/Runtime"
    ),
    .testTarget(
      name: "CoreTests",
      dependencies: ["Core"],
      path: "MorseBeaconTests/Core"
    ),
    .testTarget(
      name: "RuntimeTests",
      dependencies: ["Runtime"],
      path: "MorseBeaconTests/Runtime"
    ),
  ]
)
