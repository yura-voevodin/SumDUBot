import PackageDescription

let package = Package(
    name: "SumDUBot",
    targets: [
        Target(name: "App"),
        Target(name: "Run", dependencies: ["App"]),
        ],
    dependencies: [
        .Package(url: "https://github.com/vapor/vapor.git", majorVersion: 2),
        .Package(url: "https://github.com/vapor/fluent-provider.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/leaf-provider.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/postgresql-provider.git", majorVersion: 2),
        .Package(url: "https://github.com/BrettRToomey/Jobs.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/validation-provider.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/auth-provider.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/debugging.git", majorVersion: 1)
    ],
    exclude: [
        "Config",
        "Database",
        "Public",
        "Resources"
    ]
)
