# PLAN: HCS-008 — Global Hotkeys

## Preflight Checklist

### 1. git status
```
On branch feat/AASF-674
nothing to commit, working tree clean
```

### 2. git branch
```
+ feat/AASF-647
+ feat/AASF-671
+ feat/AASF-673
* feat/AASF-674
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-674/data/queue/: No such file or directory
```
(No queue directory exists — this is a Swift project, no stale envelopes)

### 4. Mandatory Rules from CLAUDE.md
1. Functions < 50 lines
2. Read signatures before calling
3. String matching: \b word boundaries only
4. Max 5 files per refactor commit
5. One branch at a time
6. Squash merge to main
7. Every commit: (HCS-NNN)
8. python -m pytest tests/ -q must pass before merge (N/A — Swift project uses `swift test`)

---

## Scope

| # | Action | File | Purpose |
|---|--------|------|---------|
| 1 | CREATE | `Sources/HEIMDALLControlSurface/Services/HotkeyService.swift` | Carbon/CGEvent global hotkey registration service |
| 2 | CREATE | `Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift` | Configurable key bindings with UserDefaults persistence |
| 3 | MODIFY | `Sources/HEIMDALLControlSurface/AppDelegate.swift` | Replace inline hotkey code with HotkeyService initialization |
| 4 | MODIFY | `Sources/HEIMDALLControlSurface/AppState.swift` | Add approveNext() and rejectNext() methods for hotkey actions |
| 5 | CREATE | `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift` | Unit tests for hotkey configuration persistence |

---

## Function Size Plan

### Files to Modify

**AppDelegate.swift** (current state: 103 lines):
| Function | Current Lines | After Changes | Notes |
|----------|---------------|---------------|-------|
| `applicationDidFinishLaunching` | 7 (lines 19-26) | 6 | -1: remove setupGlobalHotkey(), +0: HotkeyService init in wireHotkeys |
| `applicationWillTerminate` | 3 (lines 28-30) | 4 | +1 for HotkeyService cleanup |
| `setupGlobalHotkey` | 20 (lines 33-52) | 0 | REMOVED - moved to HotkeyService |
| `cleanupHotkey` | 8 (lines 54-61) | 0 | REMOVED - moved to HotkeyService |
| `setupNotifications` | 12 (lines 64-75) | 12 | Unchanged |
| `fourCharCode` (file-level) | 7 (lines 79-85) | 0 | REMOVED - moved to HotkeyService |
| `hotkeyHandler` (file-level) | 11 (lines 88-98) | 0 | REMOVED - moved to HotkeyService |

**AppState.swift** (current state: 138 lines):
| Function | Current Lines | After Changes | Notes |
|----------|---------------|---------------|-------|
| `toggleDashboard` | 3 (lines 47-49) | 3 | Unchanged |
| `handleApprove` | 8 (lines 114-120) | 8 | Unchanged |
| `handleReject` | 8 (lines 123-129) | 8 | Unchanged |
| NEW: `approveNext` | N/A | 8 | New function for hotkey action |
| NEW: `rejectNext` | N/A | 8 | New function for hotkey action |

### New Files (all functions < 50 lines)

**HotkeyService.swift**:
| Function | Projected Lines |
|----------|-----------------|
| `init(preferences:)` | 6 |
| `registerHotkeys(actionHandler:)` | 28 |
| `unregisterHotkeys()` | 12 |
| `checkAccessibilityPermission()` | 4 |
| `requestAccessibilityPermission()` | 6 |
| `fourCharCode(_:)` (file-level) | 7 |
| `hotkeyEventCallback` (file-level) | 15 |

**HotkeyPreferences.swift**:
| Function | Projected Lines |
|----------|-----------------|
| `init()` | 4 |
| `binding(for:)` | 4 |
| `setBinding(_:for:)` | 5 |
| `resetToDefaults()` | 8 |
| `save()` | 6 |
| `load()` | 10 |

All functions are well under 50 lines.

---

## Data Path Trace

### Hotkey Registration Flow
```
AppDelegate.applicationDidFinishLaunching() [lines 19-26]
  └─> setupNotifications() [lines 64-75]
      └─> (existing notification setup)

HeimdallApp.wireNotifications() [lines 34-45]
  └─> AppDelegate.hotkeyService getter (new)
      └─> HotkeyService.init(preferences:)
          └─> HotkeyPreferences.load() -- reads UserDefaults key "HCS.hotkeyBindings"
      └─> HotkeyService.checkAccessibilityPermission()
          └─> AXIsProcessTrusted() -- ApplicationServices API
      └─> HotkeyService.registerHotkeys(actionHandler:)
          └─> InstallEventHandler() -- Carbon API [line ~40]
          └─> for each binding in preferences.bindings:
              └─> RegisterEventHotKey() -- Carbon API [line ~50]
```

### Hotkey Trigger Flow (⌃⌥⌘H - Toggle Dashboard)
```
Carbon Event System
  └─> hotkeyEventCallback (C function pointer) [HotkeyService.swift line ~75]
      └─> GetEventParameter(kEventParamDirectObject) extracts EventHotKeyID
      └─> DispatchQueue.main.async
          └─> actionHandler(id: 1)  -- closure stored from registerHotkeys
              └─> switch id case 1:
                  └─> AppState.toggleDashboard() [AppState.swift line 47-49]
                  └─> NotificationCenter.post(.openDashboard)
                  └─> NSApp.activate(ignoringOtherApps: true)
```

### Hotkey Trigger Flow (⌃⌥⌘A - Approve Next)
```
Carbon Event System
  └─> hotkeyEventCallback [HotkeyService.swift line ~75]
      └─> DispatchQueue.main.async
          └─> actionHandler(id: 2)
              └─> switch id case 2:
                  └─> AppState.approveNext() [NEW - AppState.swift line ~57]
                      └─> guard let next = escalations.first else { return }
                      └─> Task { await handleApprove(issueId: next.issueId) }
                          └─> apiClient?.approve(id:) [line 116]
                          └─> escalations.removeAll { $0.issueId == issueId } [line 117]
```

### Hotkey Trigger Flow (⌃⌥⌘R - Reject Next)
```
Carbon Event System
  └─> hotkeyEventCallback [HotkeyService.swift line ~75]
      └─> DispatchQueue.main.async
          └─> actionHandler(id: 3)
              └─> switch id case 3:
                  └─> AppState.rejectNext() [NEW - AppState.swift line ~66]
                      └─> guard let next = escalations.first else { return }
                      └─> Task { await handleReject(issueId: next.issueId) }
                          └─> apiClient?.reject(id:reason:) [line 125]
                          └─> escalations.removeAll { $0.issueId == issueId } [line 126]
```

---

## Design

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          AppDelegate                                  │
│   hotkeyService: HotkeyService? (exposed via getter)                 │
│   applicationDidFinishLaunching: no hotkey init here                 │
│   applicationWillTerminate: hotkeyService?.unregisterHotkeys()       │
└────────────────────────────────────────────────────────────────────┬─┘
                                                                     │
                          ┌──────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       HeimdallApp.wireHotkeys()                       │
│   Creates HotkeyService, registers hotkeys with AppState closure     │
└───────────────────────────┬──────────────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────────────────┐
│  HotkeyService   │ │ HotkeyPrefs  │ │        AppState              │
│  - Carbon APIs   │ │ - UserDefaults│ │  - toggleDashboard()        │
│  - registerHot...│ │ - bindings   │ │  - approveNext() [NEW]       │
│  - unregister... │ │ - save/load  │ │  - rejectNext() [NEW]        │
└────────┬─────────┘ └──────────────┘ └──────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     Carbon Event System                               │
│   EventHotKeyRef[3] for H, A, R keys                                 │
│   EventHandlerRef for hotkey events                                  │
│   Callback → main thread → actionHandler closure                     │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### 1. HotkeyPreferences.swift (CREATE)

**Location**: `Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift`

**Purpose**: UserDefaults-backed storage for hotkey bindings.

```swift
// Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift
// HCS-008: Configurable hotkey bindings with UserDefaults persistence

import Foundation
import Carbon.HIToolbox

/// Hotkey action identifiers
public enum HotkeyAction: String, Codable, CaseIterable, Sendable {
    case toggleDashboard
    case approveNext
    case rejectNext
}

/// A single hotkey binding configuration
public struct HotkeyBinding: Codable, Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let action: HotkeyAction

    public init(keyCode: UInt32, modifiers: UInt32, action: HotkeyAction) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }
}

/// Manages hotkey bindings with UserDefaults persistence
public final class HotkeyPreferences: @unchecked Sendable {
    private static let storageKey = "HCS.hotkeyBindings"

    /// Control + Option + Command modifier mask
    public static let defaultModifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)

    /// Default hotkey bindings
    public static let defaults: [HotkeyBinding] = [
        HotkeyBinding(keyCode: 0x04, modifiers: defaultModifiers, action: .toggleDashboard), // H
        HotkeyBinding(keyCode: 0x00, modifiers: defaultModifiers, action: .approveNext),     // A
        HotkeyBinding(keyCode: 0x0F, modifiers: defaultModifiers, action: .rejectNext)       // R
    ]

    /// Current bindings
    public private(set) var bindings: [HotkeyBinding]

    public init() {
        self.bindings = Self.defaults
        load()
    }

    /// Get binding for a specific action
    public func binding(for action: HotkeyAction) -> HotkeyBinding? {
        bindings.first { $0.action == action }
    }

    /// Update binding for an action
    public func setBinding(_ binding: HotkeyBinding, for action: HotkeyAction) {
        bindings.removeAll { $0.action == action }
        bindings.append(binding)
        save()
    }

    /// Reset all bindings to defaults
    public func resetToDefaults() {
        bindings = Self.defaults
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
    }

    /// Save bindings to UserDefaults
    public func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Load bindings from UserDefaults
    public func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let loaded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) else {
            return
        }
        bindings = loaded
    }
}
```

**Line counts**: init=4, binding(for:)=4, setBinding=5, resetToDefaults=4, save=6, load=8. All under 50.

---

### 2. HotkeyService.swift (CREATE)

**Location**: `Sources/HEIMDALLControlSurface/Services/HotkeyService.swift`

**Purpose**: Carbon-based global hotkey registration service.

```swift
// Sources/HEIMDALLControlSurface/Services/HotkeyService.swift
// HCS-008: Carbon/CGEvent global hotkey registration

import AppKit
import Carbon.HIToolbox
import ApplicationServices

/// Protocol for hotkey service (enables mocking)
public protocol HotkeyServiceProtocol: AnyObject {
    var isAccessibilityEnabled: Bool { get }
    func registerHotkeys(actionHandler: @escaping (UInt32) -> Void)
    func unregisterHotkeys()
}

/// Global singleton for C callback access
private var sharedActionHandler: ((UInt32) -> Void)?

/// Carbon-based global hotkey registration service
public final class HotkeyService: HotkeyServiceProtocol {
    private let preferences: HotkeyPreferences
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    public init(preferences: HotkeyPreferences = HotkeyPreferences()) {
        self.preferences = preferences
    }

    /// Check if accessibility permission is granted
    public var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permission with system prompt
    public func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Register all hotkeys from preferences
    public func registerHotkeys(actionHandler: @escaping (UInt32) -> Void) {
        // Store handler for C callback
        sharedActionHandler = actionHandler

        // Request accessibility if needed
        if !isAccessibilityEnabled {
            requestAccessibilityPermission()
        }

        // Install event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventCallback,
            1, &eventType, nil, &eventHandler
        )
        guard status == noErr else { return }

        // Register each hotkey
        for (index, binding) in preferences.bindings.enumerated() {
            let hotkeyID = EventHotKeyID(
                signature: fourCharCode("HDAL"),
                id: UInt32(index + 1)
            )
            var hotKeyRef: EventHotKeyRef?
            RegisterEventHotKey(
                binding.keyCode,
                binding.modifiers,
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )
            if let ref = hotKeyRef {
                hotkeyRefs.append(ref)
            }
        }
    }

    /// Unregister all hotkeys and cleanup
    public func unregisterHotkeys() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        sharedActionHandler = nil
    }
}

/// Convert 4-char string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}

/// C callback for hotkey events
private func hotkeyEventCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }

    DispatchQueue.main.async {
        sharedActionHandler?(hotkeyID.id)
    }
    return noErr
}
```

**Line counts**: init=4, isAccessibilityEnabled=3, requestAccessibilityPermission=4, registerHotkeys=28, unregisterHotkeys=12, fourCharCode=7, hotkeyEventCallback=18. All under 50.

---

### 3. AppDelegate.swift (MODIFY)

**Current state**: 103 lines with inline hotkey code.

**Changes**:
1. Remove `hotkeyRef` and `eventHandler` properties (lines 11-13)
2. Add `hotkeyService` property (exposed for HeimdallApp wiring)
3. Remove `setupGlobalHotkey()` call from `applicationDidFinishLaunching` (line 23)
4. Add `hotkeyService?.unregisterHotkeys()` to `applicationWillTerminate`
5. DELETE: `setupGlobalHotkey()` method (lines 33-52)
6. DELETE: `cleanupHotkey()` method (lines 54-61)
7. DELETE: `fourCharCode()` function (lines 79-85)
8. DELETE: `hotkeyHandler` callback (lines 88-98)

**After modification** (~60 lines):
```swift
// Sources/HEIMDALLControlSurface/AppDelegate.swift
// HCS-002: Lifecycle and global hotkey setup
// HCS-008: Delegate hotkey registration to HotkeyService

import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Hotkey service for global keyboard shortcuts (HCS-008)
    private(set) var hotkeyService: HotkeyService?
    /// Notification delegate for handling user actions (HCS-006)
    private(set) var notificationDelegate: NotificationDelegate?
    /// Notification service (HCS-006)
    private(set) var notificationService: NotificationService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)
        // Set up notifications (HCS-006)
        setupNotifications()
        // Note: Hotkey registration deferred to wireHotkeys() in HeimdallApp
        // because we need AppState reference for action handler
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.unregisterHotkeys()
    }

    /// Set up notification service and request permission (HCS-006)
    private func setupNotifications() {
        notificationService = NotificationService()
        notificationService?.registerCategories()

        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate

        // Request permission (non-blocking)
        Task {
            _ = try? await notificationService?.requestAuthorization()
        }
    }

    /// Initialize hotkey service (called from HeimdallApp.wireHotkeys)
    func initializeHotkeyService() -> HotkeyService {
        let service = HotkeyService()
        self.hotkeyService = service
        return service
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}
```

---

### 4. AppState.swift (MODIFY)

**Current state**: 138 lines.

**Changes**: Add `approveNext()` and `rejectNext()` methods after `clearError()` (around line 55).

**Insert at line 55** (after clearError method):
```swift
    /// Approve the next pending escalation (for global hotkey, HCS-008)
    func approveNext() {
        guard let next = escalations.first else { return }
        Task {
            await handleApprove(issueId: next.issueId)
        }
    }

    /// Reject the next pending escalation (for global hotkey, HCS-008)
    func rejectNext() {
        guard let next = escalations.first else { return }
        Task {
            await handleReject(issueId: next.issueId)
        }
    }
```

**Line counts**: approveNext=6, rejectNext=6. Both under 50.

---

### 5. HeimdallApp.swift (MODIFY - minor)

**Current state**: 47 lines.

**Changes**: Add `wireHotkeys()` call in `onAppear` and implement the method.

**Modify `wireNotifications()` or add new method**:
```swift
    /// Wire hotkey service to AppState (HCS-008)
    private func wireHotkeys() {
        let hotkeyService = appDelegate.initializeHotkeyService()
        hotkeyService.registerHotkeys { [weak appState] hotkeyId in
            guard let appState = appState else { return }
            switch hotkeyId {
            case 1:  // Toggle Dashboard (⌃⌥⌘H)
                appState.toggleDashboard()
                NotificationCenter.default.post(name: .openDashboard, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            case 2:  // Approve Next (⌃⌥⌘A)
                appState.approveNext()
            case 3:  // Reject Next (⌃⌥⌘R)
                appState.rejectNext()
            default:
                break
            }
        }
    }
```

**Update `onAppear`**:
```swift
.onAppear {
    wireNotifications()
    wireHotkeys()  // NEW
}
```

---

### 6. HotkeyTests.swift (CREATE)

**Location**: `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift`

```swift
// Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift
// HCS-008: Unit tests for hotkey configuration persistence

import Testing
import Foundation
@testable import HEIMDALLControlSurface

// MARK: - Hotkey Preferences Tests

@Suite("Hotkey Preferences Tests")
struct HotkeyPreferencesTests {
    @Test func defaultBindingsAreSet() async throws {
        // Clear any existing preferences
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")

        let prefs = HotkeyPreferences()
        #expect(prefs.bindings.count == 3)

        let actions = prefs.bindings.map { $0.action }
        #expect(actions.contains(.toggleDashboard))
        #expect(actions.contains(.approveNext))
        #expect(actions.contains(.rejectNext))
    }

    @Test func defaultModifiersAreControlOptionCommand() async throws {
        // Control + Option + Command = 0x1500 (controlKey | optionKey | cmdKey)
        let expected = UInt32(0x1000 | 0x0800 | 0x0100)  // controlKey | optionKey | cmdKey
        #expect(HotkeyPreferences.defaultModifiers == expected)
    }

    @Test func bindingForActionReturnsCorrectBinding() async throws {
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")
        let prefs = HotkeyPreferences()

        let dashboardBinding = prefs.binding(for: .toggleDashboard)
        #expect(dashboardBinding != nil)
        #expect(dashboardBinding?.keyCode == 0x04)  // H key
        #expect(dashboardBinding?.action == .toggleDashboard)
    }

    @Test func bindingPersistenceRoundTrip() async throws {
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")

        let prefs1 = HotkeyPreferences()
        let customBinding = HotkeyBinding(
            keyCode: 0x09,  // V key
            modifiers: HotkeyPreferences.defaultModifiers,
            action: .toggleDashboard
        )
        prefs1.setBinding(customBinding, for: .toggleDashboard)

        // Create new instance to test persistence
        let prefs2 = HotkeyPreferences()
        let loaded = prefs2.binding(for: .toggleDashboard)
        #expect(loaded?.keyCode == 0x09)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")
    }

    @Test func resetToDefaultsRestoresOriginalBindings() async throws {
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")

        let prefs = HotkeyPreferences()
        let customBinding = HotkeyBinding(
            keyCode: 0x09,
            modifiers: HotkeyPreferences.defaultModifiers,
            action: .toggleDashboard
        )
        prefs.setBinding(customBinding, for: .toggleDashboard)
        #expect(prefs.binding(for: .toggleDashboard)?.keyCode == 0x09)

        prefs.resetToDefaults()
        #expect(prefs.binding(for: .toggleDashboard)?.keyCode == 0x04)  // H key
    }
}

// MARK: - Hotkey Action Tests

@Suite("Hotkey Action Tests")
struct HotkeyActionTests {
    @Test func allActionsCovered() async throws {
        let allActions = HotkeyAction.allCases
        #expect(allActions.count == 3)
        #expect(allActions.contains(.toggleDashboard))
        #expect(allActions.contains(.approveNext))
        #expect(allActions.contains(.rejectNext))
    }

    @Test func actionRawValuesAreUnique() async throws {
        let rawValues = HotkeyAction.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }

    @Test func actionRawValuesAreCamelCase() async throws {
        #expect(HotkeyAction.toggleDashboard.rawValue == "toggleDashboard")
        #expect(HotkeyAction.approveNext.rawValue == "approveNext")
        #expect(HotkeyAction.rejectNext.rawValue == "rejectNext")
    }
}

// MARK: - Hotkey Binding Tests

@Suite("Hotkey Binding Tests")
struct HotkeyBindingTests {
    @Test func bindingEquality() async throws {
        let binding1 = HotkeyBinding(keyCode: 0x04, modifiers: 0x1900, action: .toggleDashboard)
        let binding2 = HotkeyBinding(keyCode: 0x04, modifiers: 0x1900, action: .toggleDashboard)
        let binding3 = HotkeyBinding(keyCode: 0x00, modifiers: 0x1900, action: .approveNext)

        #expect(binding1 == binding2)
        #expect(binding1 != binding3)
    }

    @Test func bindingCodable() async throws {
        let binding = HotkeyBinding(keyCode: 0x04, modifiers: 0x1900, action: .toggleDashboard)

        let encoded = try JSONEncoder().encode(binding)
        let decoded = try JSONDecoder().decode(HotkeyBinding.self, from: encoded)

        #expect(decoded == binding)
    }

    @Test func defaultKeyCodesAreCorrect() async throws {
        UserDefaults.standard.removeObject(forKey: "HCS.hotkeyBindings")
        let prefs = HotkeyPreferences()

        // H = 0x04, A = 0x00, R = 0x0F
        #expect(prefs.binding(for: .toggleDashboard)?.keyCode == 0x04)
        #expect(prefs.binding(for: .approveNext)?.keyCode == 0x00)
        #expect(prefs.binding(for: .rejectNext)?.keyCode == 0x0F)
    }
}

// MARK: - AppState Hotkey Action Tests

@Suite("AppState Hotkey Action Tests")
struct AppStateHotkeyActionTests {
    @Test @MainActor func approveNextWithNoEscalationsDoesNothing() async throws {
        let appState = AppState()
        #expect(appState.escalations.isEmpty)

        // Should not crash or throw
        appState.approveNext()

        #expect(appState.escalations.isEmpty)
        #expect(appState.lastError == nil)
    }

    @Test @MainActor func rejectNextWithNoEscalationsDoesNothing() async throws {
        let appState = AppState()
        #expect(appState.escalations.isEmpty)

        // Should not crash or throw
        appState.rejectNext()

        #expect(appState.escalations.isEmpty)
        #expect(appState.lastError == nil)
    }
}
```

---

## Accessibility Permission Handling

**Requirement**: Request accessibility permission gracefully on first use.

**Implementation in HotkeyService**:
1. `isAccessibilityEnabled` checks `AXIsProcessTrusted()`
2. `requestAccessibilityPermission()` calls `AXIsProcessTrustedWithOptions()` with prompt
3. In `registerHotkeys()`, if not trusted, request permission then continue
4. Hotkeys silently fail if permission not granted (graceful degradation)

**User Experience**:
- First launch: System shows accessibility permission dialog
- If denied: Hotkeys don't work, but app functions normally
- Log warning via `print()` if permission denied

---

## Verification Plan

### Build Verification
```bash
cd /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-674
swift build
```

### Test Verification
```bash
swift test --filter HotkeyPreferencesTests
swift test --filter HotkeyActionTests
swift test --filter HotkeyBindingTests
swift test --filter AppStateHotkeyActionTests
swift test  # full suite
```

### Specific Test Files
- `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift` (CREATE)

### Manual Verification Checklist
| # | Test | Expected Result |
|---|------|-----------------|
| 1 | Launch app | Accessibility permission dialog appears (first run) |
| 2 | Grant accessibility permission | Dialog closes, no errors |
| 3 | Press ⌃⌥⌘H from any app | Dashboard window opens/toggles |
| 4 | Add mock escalation, press ⌃⌥⌘A | First escalation approved, removed from list |
| 5 | Add mock escalation, press ⌃⌥⌘R | First escalation rejected, removed from list |
| 6 | Press ⌃⌥⌘A with no escalations | No crash, no action |
| 7 | Quit and relaunch | Hotkeys still work |

### Acceptance Criteria Mapping
| Criterion | Verification |
|-----------|--------------|
| ⌃⌥⌘H toggles dashboard window from any app | Manual test #3 |
| ⌃⌥⌘A approves next pending item in queue | Manual test #4 |
| ⌃⌥⌘R rejects next pending item in queue | Manual test #5 |
| Hotkeys work when HCS is not the frontmost app | Manual tests #3-5 |
| Accessibility permission requested gracefully | Manual test #1, #2 |
| swift build succeeds, swift test passes | Build/Test verification |

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Carbon APIs deprecated | Use stable subset (EventHotKey APIs supported through macOS 14) |
| Accessibility permission denied | Graceful degradation - log warning, app still functions |
| Key code conflicts with system shortcuts | Use ⌃⌥⌘ modifier combo (rarely used by system) |
| Thread safety in C callback | Dispatch to main thread immediately via `DispatchQueue.main.async` |
| Memory leak from global callback pointer | Clear `sharedActionHandler` in `unregisterHotkeys()` |

---

## Execution Contract

```json
{
  "issue_ref": "HCS-008",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift",
      "function": "HotkeyPreferences class, HotkeyBinding struct, HotkeyAction enum",
      "change_description": "CREATE: UserDefaults-backed hotkey binding storage with HotkeyBinding struct, HotkeyAction enum, and persistence methods (save/load/resetToDefaults)",
      "verification": "swift test --filter HotkeyPreferencesTests passes"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/HotkeyService.swift",
      "function": "HotkeyService class, HotkeyServiceProtocol",
      "change_description": "CREATE: Carbon-based global hotkey registration with registerHotkeys(actionHandler:), unregisterHotkeys(), accessibility permission handling, and C callback for event dispatch",
      "verification": "swift build succeeds; hotkeys functional in manual test"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppDelegate.swift",
      "function": "applicationWillTerminate, initializeHotkeyService",
      "change_description": "MODIFY: Remove inline hotkey code (setupGlobalHotkey, cleanupHotkey, fourCharCode, hotkeyHandler); add hotkeyService property and initializeHotkeyService() factory; add cleanup call in applicationWillTerminate",
      "verification": "swift build succeeds; Carbon import removed"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppState.swift",
      "function": "approveNext, rejectNext",
      "change_description": "MODIFY: Add approveNext() and rejectNext() methods that process the first pending escalation via handleApprove/handleReject",
      "verification": "swift test --filter AppStateHotkeyActionTests passes"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/HeimdallApp.swift",
      "function": "wireHotkeys",
      "change_description": "MODIFY: Add wireHotkeys() method to register hotkeys with AppState action closure; call from onAppear alongside wireNotifications()",
      "verification": "swift build succeeds; hotkeys dispatch to correct AppState methods"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift",
      "function": "HotkeyPreferencesTests, HotkeyActionTests, HotkeyBindingTests, AppStateHotkeyActionTests",
      "change_description": "CREATE: Unit tests for hotkey preferences persistence, binding equality/codable, action enum coverage, and AppState hotkey methods",
      "verification": "swift test --filter HotkeyTests passes all tests"
    }
  ]
}
```
