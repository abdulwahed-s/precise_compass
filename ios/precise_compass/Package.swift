// swift-tools-version: 5.9
// The Swift Package Manager manifest for the iOS implementation of
// precise_compass. The same sources back the CocoaPods podspec, so the plugin
// supports both integrations.
import PackageDescription

let package = Package(
  name: "precise_compass",
  platforms: [
    .iOS("12.0"),
  ],
  products: [
    .library(name: "precise-compass", targets: ["precise_compass"]),
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
  ],
  targets: [
    .target(
      name: "precise_compass",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework"),
      ],
      resources: []
    ),
  ]
)
