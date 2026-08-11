// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LineWise",
  platforms: [.macOS(.v12), .iOS(.v15), .watchOS(.v8)],
  products: [
    .library(name: "LineWiseDomain", targets: ["LineWiseDomain"]),
    .library(name: "LineWiseApplication", targets: ["LineWiseApplication"]),
    .library(name: "LineWiseAppleAdapters", targets: ["LineWiseAppleAdapters"]),
    .library(name: "LineWiseAIAdapters", targets: ["LineWiseAIAdapters"]),
    .executable(name: "linewise-demo", targets: ["LineWiseDemo"]),
  ],
  targets: [
    .target(name: "LineWiseDomain"),
    .target(name: "LineWiseApplication", dependencies: ["LineWiseDomain"]),
    .target(
      name: "LineWiseAppleAdapters",
      dependencies: ["LineWiseDomain", "LineWiseApplication", "LineWiseAIAdapters"]
    ),
    .target(name: "LineWiseAIAdapters", dependencies: ["LineWiseDomain"]),
    .executableTarget(
      name: "LineWiseDemo",
      dependencies: ["LineWiseDomain", "LineWiseApplication", "LineWiseAppleAdapters"]
    ),
    .executableTarget(
      name: "LineWiseDomainSpec",
      dependencies: ["LineWiseDomain"],
      path: "Specs/LineWiseDomainSpec"
    ),
    .executableTarget(
      name: "LineWiseApplicationSpec",
      dependencies: ["LineWiseDomain", "LineWiseApplication", "LineWiseAppleAdapters"],
      path: "Specs/LineWiseApplicationSpec"
    ),
    .executableTarget(
      name: "LineWiseAppleAdaptersSpec",
      dependencies: ["LineWiseDomain", "LineWiseAppleAdapters"],
      path: "Specs/LineWiseAppleAdaptersSpec"
    ),
    .executableTarget(
      name: "LineWiseAIAdaptersSpec",
      dependencies: ["LineWiseDomain", "LineWiseAIAdapters"],
      path: "Specs/LineWiseAIAdaptersSpec"
    ),
  ]
)
