// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SolitaireEngine", platforms: [.iOS(.v16), .macOS(.v13)], products: [.library(name: "SolitaireEngine", targets: ["SolitaireEngine"])], targets: [.target(name: "SolitaireEngine"), .testTarget(name: "SolitaireEngineTests", dependencies: ["SolitaireEngine"])])
