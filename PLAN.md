# PLAN: HCS-001 SPM Project Scaffold

## Preflight Checklist

### 1. git status
```
On branch feat/AASF-645
nothing to commit, working tree clean
```

### 2. git branch
```
* feat/AASF-645
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-645/data/queue/: No such file or directory
```

### 4. Mandatory Rules from CLAUDE.md
1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. python -m pytest tests/ -q must pass before merge

---

## Scope

Create the Swift Package Manager project structure for HEIMDALL Control Surface (HCS), a macOS monitoring and control dashboard application using SwiftUI, SwiftData, and Swift Charts.

**What this plan covers:**
- Package.swift manifest with all dependencies
- Sources/ directory with organized module structure
- Tests/ directory with test target stubs
- Resources/ directory with asset catalog
- Swift-specific .gitignore additions
- README.md with build instructions

**What this plan does NOT cover:**
- Actual application logic implementation
- UI design beyond placeholder files
- Data model implementation details

---

## Analysis

### Current State
- Worktree contains only Heimdall configuration files (.agent/, docs/, CLAUDE.md, GEMINI.md)
- No Swift files exist - greenfield project
- Swift 6.3 is available on host system
- Existing .gitignore covers Python but not Swift

### Target State
Standard SPM executable package structure with:
- Single executable target: `HEIMDALLControlSurface`
- Test target: `HEIMDALLControlSurfaceTests`
- Organized source subdirectories for Models, Views, Services

---

## File Operations Table

| Operation | Path | Description |
|-----------|------|-------------|
| CREATE | Package.swift | SPM manifest with SwiftUI, SwiftData, Charts |
| CREATE | Sources/HEIMDALLControlSurface/App.swift | Main app entry point |
| CREATE | Sources/HEIMDALLControlSurface/ContentView.swift | Root view placeholder |
| CREATE | Sources/HEIMDALLControlSurface/Models/.gitkeep | Models directory placeholder |
| CREATE | Sources/HEIMDALLControlSurface/Views/.gitkeep | Views directory placeholder |
| CREATE | Sources/HEIMDALLControlSurface/Services/.gitkeep | Services directory placeholder |
| CREATE | Tests/HEIMDALLControlSurfaceTests/ModelTests.swift | Model test placeholder |
| CREATE | Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift | Service test placeholder |
| CREATE | Tests/HEIMDALLControlSurfaceTests/ViewTests.swift | View test placeholder |
| CREATE | Resources/Assets.xcassets/Contents.json | Asset catalog root |
| CREATE | Resources/Assets.xcassets/AppIcon.appiconset/Contents.json | App icon set |
| CREATE | README.md | Build instructions |
| MODIFY | .gitignore | Add Swift-specific ignores |

---

## Detailed Implementation

### 1. Package.swift

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HEIMDALLControlSurface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "HEIMDALLControlSurface",
            targets: ["HEIMDALLControlSurface"]
        )
    ],
    targets: [
        .executableTarget(
            name: "HEIMDALLControlSurface",
            resources: [
                .process("../../Resources")
            ]
        ),
        .testTarget(
            name: "HEIMDALLControlSurfaceTests",
            dependencies: ["HEIMDALLControlSurface"]
        )
    ]
)
```

**Notes:**
- macOS 14+ required for SwiftData
- SwiftUI, SwiftData, and Charts are part of SDK (no external dependencies)
- Resources processed from Resources/ directory

### 2. Sources/HEIMDALLControlSurface/App.swift

```swift
import SwiftUI
import SwiftData

@main
struct HEIMDALLControlSurfaceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Sources/HEIMDALLControlSurface/ContentView.swift

```swift
import SwiftUI
import Charts

struct ContentView: View {
    var body: some View {
        VStack {
            Text("HEIMDALL Control Surface")
                .font(.largeTitle)
            Text("v0.1.0")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
```

### 4. Test Files

**Tests/HEIMDALLControlSurfaceTests/ModelTests.swift:**
```swift
import Testing
@testable import HEIMDALLControlSurface

@Suite("Model Tests")
struct ModelTests {
    @Test func placeholder() async throws {
        // Placeholder test - to be implemented with models
        #expect(true)
    }
}
```

**Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift:**
```swift
import Testing
@testable import HEIMDALLControlSurface

@Suite("Service Tests")
struct ServiceTests {
    @Test func placeholder() async throws {
        // Placeholder test - to be implemented with services
        #expect(true)
    }
}
```

**Tests/HEIMDALLControlSurfaceTests/ViewTests.swift:**
```swift
import Testing
@testable import HEIMDALLControlSurface

@Suite("View Tests")
struct ViewTests {
    @Test func placeholder() async throws {
        // Placeholder test - to be implemented with views
        #expect(true)
    }
}
```

### 5. Resources/Assets.xcassets

**Resources/Assets.xcassets/Contents.json:**
```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**Resources/Assets.xcassets/AppIcon.appiconset/Contents.json:**
```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

### 6. README.md

```markdown
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
```

### 7. .gitignore Additions

Append to existing .gitignore:
```
# Swift
.build/
.swiftpm/
Package.resolved
*.xcodeproj
*.xcworkspace
DerivedData/
xcuserdata/
```

---

## Function Size Plan

**Not applicable** - All files are new creations with minimal code. No existing functions to modify. All new functions are under 10 lines.

| File | Function | Lines |
|------|----------|-------|
| App.swift | body (computed property) | 5 |
| ContentView.swift | body (computed property) | 9 |
| ModelTests.swift | placeholder() | 3 |
| ServiceTests.swift | placeholder() | 3 |
| ViewTests.swift | placeholder() | 3 |

---

## Verification Plan

### Automated Verification
1. **Build verification**: `swift build` must complete without errors
2. **Test verification**: `swift test` must run and pass all placeholder tests
3. **No .xcodeproj check**: Verify no Xcode project files exist

### Manual Verification Checklist
- [ ] Package.swift declares macOS 14+ platform
- [ ] Sources/ directory structure matches specification
- [ ] Tests/ contains ModelTests, ServiceTests, ViewTests
- [ ] Resources/ contains Assets.xcassets
- [ ] README.md includes build instructions
- [ ] .gitignore includes Swift patterns

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Swift 6 syntax changes | Using stable APIs only |
| Resource path resolution | Using .process() for automatic handling |
| SwiftData import in App.swift | Required for future @Model decorators |

---

## Execution Contract

```json
{
  "issue_ref": "HCS-001",
  "deliverables": [
    {
      "file": "Package.swift",
      "function": "",
      "change_description": "CREATE SPM manifest with macOS 14+ platform, executable target, test target, and resource processing",
      "verification": "swift build succeeds"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/App.swift",
      "function": "HEIMDALLControlSurfaceApp",
      "change_description": "CREATE main app entry point with @main attribute and WindowGroup scene",
      "verification": "swift build succeeds, app launches"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/ContentView.swift",
      "function": "ContentView",
      "change_description": "CREATE root SwiftUI view with placeholder content importing Charts",
      "verification": "swift build succeeds"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Models/.gitkeep",
      "function": "",
      "change_description": "CREATE empty placeholder for Models directory",
      "verification": "Directory exists"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Views/.gitkeep",
      "function": "",
      "change_description": "CREATE empty placeholder for Views directory",
      "verification": "Directory exists"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/.gitkeep",
      "function": "",
      "change_description": "CREATE empty placeholder for Services directory",
      "verification": "Directory exists"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ModelTests.swift",
      "function": "ModelTests",
      "change_description": "CREATE test suite with placeholder test using Swift Testing framework",
      "verification": "swift test passes"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift",
      "function": "ServiceTests",
      "change_description": "CREATE test suite with placeholder test using Swift Testing framework",
      "verification": "swift test passes"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ViewTests.swift",
      "function": "ViewTests",
      "change_description": "CREATE test suite with placeholder test using Swift Testing framework",
      "verification": "swift test passes"
    },
    {
      "file": "Resources/Assets.xcassets/Contents.json",
      "function": "",
      "change_description": "CREATE asset catalog root manifest",
      "verification": "Valid JSON, swift build succeeds"
    },
    {
      "file": "Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
      "function": "",
      "change_description": "CREATE app icon set manifest for macOS icons",
      "verification": "Valid JSON with macOS icon sizes"
    },
    {
      "file": "README.md",
      "function": "",
      "change_description": "CREATE project documentation with build instructions, structure, and requirements",
      "verification": "Contains swift build/run/test commands"
    },
    {
      "file": ".gitignore",
      "function": "",
      "change_description": "MODIFY to append Swift-specific ignore patterns (.build/, .swiftpm/, etc.)",
      "verification": ".build/ and .swiftpm/ patterns present"
    }
  ]
}
```
