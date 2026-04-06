# HEIMDALL Control Surface

A macOS application for monitoring and controlling HEIMDALL-managed projects.

## Requirements

- macOS 14.0+
- Swift 6.0+
- Xcode 16.0+ (for development)

## Build

```bash
swift build
```

## Run

```bash
swift run
```

## Test

```bash
swift test
```

## Project Structure

```
HEIMDALLControlSurface/
├── Package.swift
├── Sources/
│   └── HEIMDALLControlSurface/
│       ├── App.swift              # Application entry point
│       ├── ContentView.swift      # Root view
│       ├── Models/                # Data models (SwiftData)
│       ├── Views/                 # SwiftUI views
│       └── Services/              # Business logic & API clients
├── Tests/
│   └── HEIMDALLControlSurfaceTests/
│       ├── ModelTests.swift
│       ├── ServiceTests.swift
│       └── ViewTests.swift
└── Resources/
    └── Assets.xcassets/           # App icons and images
```

## Architecture

- **SwiftUI** - Declarative UI framework
- **SwiftData** - Data persistence
- **Swift Charts** - Data visualization

## License

Proprietary - Solutions4.AI
