// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "flutter_notemus",
  platforms: [
    .iOS(.v13),
  ],
  products: [
    .library(name: "flutter-notemus", targets: ["flutter_notemus"]),
  ],
  targets: [
    .target(
      name: "flutter_notemus",
      path: "Sources/flutter_notemus"
    ),
  ]
)
