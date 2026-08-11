// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "LineWise",
  products: [
    .library(name: "LineWiseDomain", targets: ["LineWiseDomain"])
  ],
  targets: [
    .target(name: "LineWiseDomain"),
    .executableTarget(
      name: "LineWiseDomainSpec",
      dependencies: ["LineWiseDomain"],
      path: "Specs/LineWiseDomainSpec"
    ),
  ]
)
