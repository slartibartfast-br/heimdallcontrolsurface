# PLAN: HCS-008 — Global Hotkeys

## Preflight Checklist

### 1. git status
```
On branch feat/HCS-008
nothing to commit, working tree clean
```

### 2. git branch
```
  feat/AASF-647
  feat/AASF-673
* feat/HCS-008
+ main
```

### 3. ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-674/data/queue/: No such file or directory
```
(No queue directory — this is a Swift project, no stale envelopes)

### 4. CLAUDE.md Mandatory Rules
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

| # | File | Action | Purpose |
|---|------|--------|---------|
| 1 | `Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift` | CREATE | UserDefaults-backed key binding storage |
| 2 | `Sources/HEIMDALLControlSurface/Services/HotkeyService.swift` | CREATE | Carbon API global hotkey registration service |
| 3 | `Sources/HEIMDALLControlSurface/AppDelegate.swift` | MODIFY | Remove inline hotkey code, delegate to HotkeyService |
| 4 | `Sources/HEIMDALLControlSurface/AppState.swift` | MODIFY | Add `approveNext()` and `rejectNext()` methods |
| 5 | `Sources/HEIMDALLControlSurface/HeimdallApp.swift` | MODIFY | Add `wireHotkeys()` method to connect actions |
| 6 | `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift` | CREATE | Unit tests for hotkey configuration persistence |

---

## Data Path Trace

**Hotkey Registration Flow:**
```
AppDelegate.applicationDidFinishLaunching() → HotkeyService.init()
    ↓
HeimdallApp.wireHotkeys() → HotkeyService.setHandler(for:handler:) [x3]
    ↓
HotkeyService.registerHotkeys() → checkAccessibility() → installEventHandler()
    ↓
HotkeyService.registerHotkey(for:id:) → HotkeyPreferences.binding(for:)
    ↓
Carbon RegisterEventHotKey(keyCode, modifiers, hotkeyID, target, options, &ref)
```

**Hotkey Execution Flow:**
```
User presses ⌃⌥⌘H/A/R → Carbon Event System
    ↓
hotkeyCallback() → GetEventParameter() → extract hotkeyID
    ↓
DispatchQueue.main.async → HotkeyService.shared?.handleHotkeyEvent(id:)
    ↓
HotkeyService.actionHandlers[hotkeyID]() → closure execution
```

**Action Execution:**
```
⌃⌥⌘H → AppState.toggleDashboard() + NotificationCenter.post(.openDashboard) + NSApp.activate()
⌃⌥⌘A → AppState.approveNext() → apiClient?.approve(id:) → pendingApprovals.removeFirst()
⌃⌥⌘R → AppState.rejectNext() → apiClient?.reject(id:reason:) → pendingApprovals.removeFirst()
```

**Preferences Flow:**
```
HotkeyPreferences.binding(for:) → UserDefaults.data(forKey:) → JSONDecoder.decode() OR defaultBindings[action]
HotkeyPreferences.setBinding(_:for:) → JSONEncoder.encode() → UserDefaults.set(_:forKey:)
```

---

## Function Size Plan

**Existing functions in files to modify (all < 50 lines):**

| File | Function | Current Lines | After Changes |
|------|----------|---------------|---------------|
| AppDelegate.swift | applicationDidFinishLaunching() | 7 | 8 (add setupHotkeyService call) |
| AppDelegate.swift | applicationWillTerminate() | 2 | 4 (add hotkeyService cleanup) |
| AppDelegate.swift | setupGlobalHotkey() | 19 | REMOVED |
| AppDelegate.swift | cleanupHotkey() | 7 | REMOVED |
| AppState.swift | all existing | < 15 each | unchanged |
| HeimdallApp.swift | wireNotifications() | 11 | unchanged |

**New functions (all < 50 lines):**

| File | Function | Projected Lines | Status |
|------|----------|-----------------|--------|
| HotkeyPreferences.swift | binding(for:) | 8 | ✓ |
| HotkeyPreferences.swift | setBinding(_:for:) | 5 | ✓ |
| HotkeyPreferences.swift | resetToDefault(for:) | 3 | ✓ |
| HotkeyService.swift | checkAccessibility() | 4 | ✓ |
| HotkeyService.swift | registerHotkeys() | 6 | ✓ |
| HotkeyService.swift | unregisterAll() | 9 | ✓ |
| HotkeyService.swift | setHandler(for:handler:) | 4 | ✓ |
| HotkeyService.swift | installEventHandler() | 8 | ✓ |
| HotkeyService.swift | registerHotkey(for:id:) | 12 | ✓ |
| HotkeyService.swift | handleHotkeyEvent(id:) | 4 | ✓ |
| AppState.swift | approveNext() | 10 | ✓ |
| AppState.swift | rejectNext() | 10 | ✓ |
| HeimdallApp.swift | wireHotkeys() | 18 | ✓ |

No functions exceed 50 lines. No helper extraction required.

---

## Detailed Design

### 1. HotkeyPreferences.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift`

```swift
// Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift
// HCS-008: UserDefaults-backed hotkey configuration

import Foundation
import Carbon.HIToolbox

/// Hotkey action identifiers
public enum HotkeyAction: String, CaseIterable, Sendable {
    case toggleDashboard = "toggleDashboard"
    case approveNext = "approveNext"
    case rejectNext = "rejectNext"
}

/// Stored key binding configuration
public struct HotkeyBinding: Codable, Sendable, Equatable {
    public let keyCode: UInt32
    public let modifiers: UInt32  // Carbon modifier flags

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

/// UserDefaults-backed preferences for hotkey bindings
public final class HotkeyPreferences: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix = "com.heimdall.hcs.hotkey."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Get binding for action (returns default if not set)
    public func binding(for action: HotkeyAction) -> HotkeyBinding {
        let key = keyPrefix + action.rawValue
        if let data = defaults.data(forKey: key),
           let binding = try? JSONDecoder().decode(HotkeyBinding.self, from: data) {
            return binding
        }
        return Self.defaultBindings[action]!
    }

    /// Set custom binding for action
    public func setBinding(_ binding: HotkeyBinding, for action: HotkeyAction) {
        let key = keyPrefix + action.rawValue
        if let data = try? JSONEncoder().encode(binding) {
            defaults.set(data, forKey: key)
        }
    }

    /// Reset action to default binding
    public func resetToDefault(for action: HotkeyAction) {
        let key = keyPrefix + action.rawValue
        defaults.removeObject(forKey: key)
    }

    /// Default hotkey bindings (⌃⌥⌘ + key)
    public static let defaultBindings: [HotkeyAction: HotkeyBinding] = [
        .toggleDashboard: HotkeyBinding(keyCode: 0x04, modifiers: UInt32(controlKey | optionKey | cmdKey)),  // H
        .approveNext: HotkeyBinding(keyCode: 0x00, modifiers: UInt32(controlKey | optionKey | cmdKey)),      // A
        .rejectNext: HotkeyBinding(keyCode: 0x0F, modifiers: UInt32(controlKey | optionKey | cmdKey))        // R
    ]
}
```

**Key codes (from Carbon):**
- H = 0x04 (kVK_ANSI_H)
- A = 0x00 (kVK_ANSI_A)
- R = 0x0F (kVK_ANSI_R)

**Modifiers:** `controlKey | optionKey | cmdKey` = ⌃⌥⌘

---

### 2. HotkeyService.swift (CREATE)

**Location:** `Sources/HEIMDALLControlSurface/Services/HotkeyService.swift`

```swift
// Sources/HEIMDALLControlSurface/Services/HotkeyService.swift
// HCS-008: Carbon API global hotkey registration

import AppKit
import Carbon.HIToolbox

/// Protocol for testability
public protocol HotkeyServiceProtocol: Sendable {
    func registerHotkeys()
    func unregisterAll()
    func setHandler(for action: HotkeyAction, handler: @escaping @Sendable () -> Void)
}

/// Global hotkey service using Carbon Event APIs
@MainActor
public final class HotkeyService: HotkeyServiceProtocol {
    private let preferences: HotkeyPreferences
    private var hotkeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var actionHandlers: [UInt32: @Sendable () -> Void] = [:]

    /// Shared instance for C callback access
    nonisolated(unsafe) private static var shared: HotkeyService?

    public init(preferences: HotkeyPreferences = HotkeyPreferences()) {
        self.preferences = preferences
        Self.shared = self
    }

    /// Check and request accessibility permission
    public func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Register all configured hotkeys
    public func registerHotkeys() {
        guard checkAccessibility() else { return }
        installEventHandler()
        for (index, action) in HotkeyAction.allCases.enumerated() {
            registerHotkey(for: action, id: UInt32(index + 1))
        }
    }

    /// Unregister all hotkeys and cleanup
    public func unregisterAll() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    /// Set handler for specific action
    public func setHandler(for action: HotkeyAction, handler: @escaping @Sendable () -> Void) {
        let index = HotkeyAction.allCases.firstIndex(of: action)!
        actionHandlers[UInt32(index + 1)] = handler
    }

    // MARK: - Private

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1, &eventType, nil, &eventHandler
        )
    }

    private func registerHotkey(for action: HotkeyAction, id: UInt32) {
        let binding = preferences.binding(for: action)
        let hotkeyID = EventHotKeyID(signature: fourCharCode("HDAL"), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode, binding.modifiers, hotkeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        if status == noErr, let ref = hotKeyRef {
            hotkeyRefs[action] = ref
        }
    }

    /// Dispatch hotkey event to appropriate handler
    fileprivate func handleHotkeyEvent(id: UInt32) {
        if let handler = actionHandlers[id] {
            handler()
        }
    }
}

// MARK: - C Callback

private func hotkeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotkeyID = EventHotKeyID()
    GetEventParameter(
        event, EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID
    )
    DispatchQueue.main.async {
        HotkeyService.shared?.handleHotkeyEvent(id: hotkeyID.id)
    }
    return noErr
}

/// Converts 4-char string to OSType
private func fourCharCode(_ string: String) -> OSType {
    var result: OSType = 0
    for char in string.utf8.prefix(4) {
        result = (result << 8) + OSType(char)
    }
    return result
}
```

---

### 3. AppDelegate.swift (MODIFY)

**Current state:** 102 lines with inline hotkey setup using Cmd+Shift+H.

**Changes:**
1. Remove properties: `hotkeyRef`, `eventHandler` (lines 10-13)
2. Remove methods: `setupGlobalHotkey()` (lines 32-52), `cleanupHotkey()` (lines 54-61)
3. Remove top-level functions: `fourCharCode()` (lines 78-85), `hotkeyHandler()` (lines 87-98)
4. Add property: `hotkeyService: HotkeyService?`
5. Update `applicationDidFinishLaunching()`: remove `setupGlobalHotkey()` call, add `hotkeyService = HotkeyService()`
6. Update `applicationWillTerminate()`: replace `cleanupHotkey()` with `hotkeyService?.unregisterAll()`
7. Keep: `Notification.Name.openDashboard` extension (used by HeimdallApp.wireHotkeys)

**After modification (approximately 50 lines):**
```swift
// Sources/HEIMDALLControlSurface/AppDelegate.swift
// HCS-002: Lifecycle
// HCS-008: HotkeyService initialization

import AppKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Notification delegate for handling user actions (HCS-006)
    private(set) var notificationDelegate: NotificationDelegate?
    /// Notification service (HCS-006)
    private(set) var notificationService: NotificationService?
    /// Hotkey service (HCS-008)
    private(set) var hotkeyService: HotkeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupNotifications()
        hotkeyService = HotkeyService()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService?.unregisterAll()
    }

    /// Set up notification service and request permission (HCS-006)
    private func setupNotifications() {
        notificationService = NotificationService()
        notificationService?.registerCategories()

        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate

        Task {
            _ = try? await notificationService?.requestAuthorization()
        }
    }
}

extension Notification.Name {
    static let openDashboard = Notification.Name("openDashboard")
}
```

---

### 4. AppState.swift (MODIFY)

**Current state:** 202 lines. Add two new methods after line 128 (after `cleanupAction`).

**Add after MARK: - Pending Approvals section:**

```swift
// MARK: - Global Hotkey Actions (HCS-008)

/// Approve the next pending item in queue
func approveNext() async {
    guard let approval = pendingApprovals.first else { return }
    do {
        _ = try await apiClient?.approve(id: approval.id)
        pendingApprovals.removeFirst()
    } catch {
        lastError = "Approve failed: \(error.localizedDescription)"
    }
}

/// Reject the next pending item in queue
func rejectNext() async {
    guard let approval = pendingApprovals.first else { return }
    do {
        _ = try await apiClient?.reject(id: approval.id, reason: nil)
        pendingApprovals.removeFirst()
    } catch {
        lastError = "Reject failed: \(error.localizedDescription)"
    }
}
```

**Projected line count:** 222 lines (original 202 + 20 new)

---

### 5. HeimdallApp.swift (MODIFY)

**Current state:** 46 lines.

**Changes:**
1. Add `wireHotkeys()` method after `wireNotifications()`
2. Call `wireHotkeys()` from `.onAppear` closure

**Add after wireNotifications():**
```swift
/// Wire global hotkey handlers (HCS-008)
private func wireHotkeys() {
    guard let hotkeyService = appDelegate.hotkeyService else { return }

    hotkeyService.setHandler(for: .toggleDashboard) { [weak appState] in
        appState?.toggleDashboard()
        NotificationCenter.default.post(name: .openDashboard, object: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    hotkeyService.setHandler(for: .approveNext) { [weak appState] in
        Task { @MainActor in await appState?.approveNext() }
    }

    hotkeyService.setHandler(for: .rejectNext) { [weak appState] in
        Task { @MainActor in await appState?.rejectNext() }
    }

    hotkeyService.registerHotkeys()
}
```

**Update .onAppear:**
```swift
.onAppear {
    wireNotifications()
    wireHotkeys()
}
```

**Projected line count:** 65 lines (original 46 + 19 new)

---

### 6. HotkeyTests.swift (CREATE)

**Location:** `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift`

```swift
// Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift
// HCS-008: Hotkey configuration persistence tests

import Testing
import Foundation
import Carbon.HIToolbox
@testable import HEIMDALLControlSurface

@Suite("Hotkey Preferences Tests")
struct HotkeyPreferencesTests {

    @Test func defaultBindingsExistForAllActions() async throws {
        let prefs = HotkeyPreferences()
        for action in HotkeyAction.allCases {
            let binding = prefs.binding(for: action)
            #expect(binding.modifiers != 0)
        }
    }

    @Test func defaultToggleDashboardIsControlOptionCommandH() async throws {
        let prefs = HotkeyPreferences()
        let binding = prefs.binding(for: .toggleDashboard)
        #expect(binding.keyCode == 0x04)  // H
        let expectedMods = UInt32(controlKey | optionKey | cmdKey)
        #expect(binding.modifiers == expectedMods)
    }

    @Test func defaultApproveNextIsControlOptionCommandA() async throws {
        let prefs = HotkeyPreferences()
        let binding = prefs.binding(for: .approveNext)
        #expect(binding.keyCode == 0x00)  // A
        let expectedMods = UInt32(controlKey | optionKey | cmdKey)
        #expect(binding.modifiers == expectedMods)
    }

    @Test func defaultRejectNextIsControlOptionCommandR() async throws {
        let prefs = HotkeyPreferences()
        let binding = prefs.binding(for: .rejectNext)
        #expect(binding.keyCode == 0x0F)  // R
        let expectedMods = UInt32(controlKey | optionKey | cmdKey)
        #expect(binding.modifiers == expectedMods)
    }

    @Test func customBindingPersistsToUserDefaults() async throws {
        let testDefaults = UserDefaults(suiteName: "HCS008Test")!
        testDefaults.removePersistentDomain(forName: "HCS008Test")

        let prefs = HotkeyPreferences(defaults: testDefaults)
        let customBinding = HotkeyBinding(keyCode: 0x0D, modifiers: UInt32(cmdKey))

        prefs.setBinding(customBinding, for: .toggleDashboard)
        let retrieved = prefs.binding(for: .toggleDashboard)

        #expect(retrieved == customBinding)
        testDefaults.removePersistentDomain(forName: "HCS008Test")
    }

    @Test func resetToDefaultRemovesCustomBinding() async throws {
        let testDefaults = UserDefaults(suiteName: "HCS008ResetTest")!
        testDefaults.removePersistentDomain(forName: "HCS008ResetTest")

        let prefs = HotkeyPreferences(defaults: testDefaults)
        let customBinding = HotkeyBinding(keyCode: 0x0D, modifiers: UInt32(cmdKey))

        prefs.setBinding(customBinding, for: .approveNext)
        prefs.resetToDefault(for: .approveNext)

        let retrieved = prefs.binding(for: .approveNext)
        let defaultBinding = HotkeyPreferences.defaultBindings[.approveNext]!
        #expect(retrieved == defaultBinding)

        testDefaults.removePersistentDomain(forName: "HCS008ResetTest")
    }

    @Test func hotkeyBindingEquality() async throws {
        let b1 = HotkeyBinding(keyCode: 0x04, modifiers: 123)
        let b2 = HotkeyBinding(keyCode: 0x04, modifiers: 123)
        let b3 = HotkeyBinding(keyCode: 0x05, modifiers: 123)

        #expect(b1 == b2)
        #expect(b1 != b3)
    }

    @Test func hotkeyActionRawValues() async throws {
        #expect(HotkeyAction.toggleDashboard.rawValue == "toggleDashboard")
        #expect(HotkeyAction.approveNext.rawValue == "approveNext")
        #expect(HotkeyAction.rejectNext.rawValue == "rejectNext")
    }

    @Test func hotkeyActionAllCasesCount() async throws {
        #expect(HotkeyAction.allCases.count == 3)
    }
}

@Suite("Hotkey Action Tests")
struct HotkeyActionTests {

    @Test @MainActor func approveNextRemovesFirstPendingApproval() async throws {
        let appState = AppState()
        let mockAPI = MockAPIClient()
        let mockNotification = MockNotificationService()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI)

        // Add test approvals
        let approval = Approval(
            id: "test-1",
            issueId: "HCS-001",
            phase: "review",
            reason: "Test",
            agent: "test-agent"
        )
        appState.pendingApprovals = [approval]

        await appState.approveNext()

        #expect(appState.pendingApprovals.isEmpty)
    }

    @Test @MainActor func rejectNextRemovesFirstPendingApproval() async throws {
        let appState = AppState()
        let mockAPI = MockAPIClient()
        let mockNotification = MockNotificationService()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI)

        let approval = Approval(
            id: "test-2",
            issueId: "HCS-002",
            phase: "review",
            reason: "Test",
            agent: "test-agent"
        )
        appState.pendingApprovals = [approval]

        await appState.rejectNext()

        #expect(appState.pendingApprovals.isEmpty)
    }

    @Test @MainActor func approveNextWithEmptyQueueDoesNothing() async throws {
        let appState = AppState()
        let mockAPI = MockAPIClient()
        let mockNotification = MockNotificationService()
        appState.configure(notificationService: mockNotification, apiClient: mockAPI)

        appState.pendingApprovals = []

        await appState.approveNext()

        #expect(appState.lastError == nil)
    }
}
```

---

## Guard / Recovery Pairs

| Guard | Location | Recovery |
|-------|----------|----------|
| `checkAccessibility()` returns false | HotkeyService.registerHotkeys() | Skip registration; system prompts user for permission |
| `apiClient` is nil | AppState.approveNext() / rejectNext() | Guard returns early, no action taken |
| `pendingApprovals.first` is nil | AppState.approveNext() / rejectNext() | Guard returns early, no action taken |
| `RegisterEventHotKey` returns error | HotkeyService.registerHotkey() | Skip that hotkey, continue registering others |
| JSON decode fails | HotkeyPreferences.binding(for:) | Return default binding from `defaultBindings` |
| `hotkeyService` is nil | HeimdallApp.wireHotkeys() | Guard returns early, no wiring |

---

## Verification Plan

| Check | Command/Method | Expected |
|-------|----------------|----------|
| Build succeeds | `swift build` | Exit 0, no errors |
| Tests pass | `swift test` | All tests green |
| Preferences persist | Run HotkeyPreferencesTests | Custom bindings stored/retrieved correctly |
| Default bindings correct | Run HotkeyPreferencesTests | ⌃⌥⌘H/A/R verified with correct key codes |
| Accessibility prompt | Launch app without permission | System accessibility dialog appears |
| Toggle dashboard | Press ⌃⌥⌘H from any app | Dashboard window toggles visibility |
| Approve next | Press ⌃⌥⌘A with pending item | First item approved, removed from queue |
| Reject next | Press ⌃⌥⌘R with pending item | First item rejected, removed from queue |

---

## Test Strategy

### Test Files
- `Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift` (CREATE)

### Test Cases

| Suite | Test | Verification |
|-------|------|--------------|
| HotkeyPreferencesTests | defaultBindingsExistForAllActions | All actions have non-zero modifiers |
| HotkeyPreferencesTests | defaultToggleDashboardIsControlOptionCommandH | keyCode=0x04, mods=⌃⌥⌘ |
| HotkeyPreferencesTests | defaultApproveNextIsControlOptionCommandA | keyCode=0x00, mods=⌃⌥⌘ |
| HotkeyPreferencesTests | defaultRejectNextIsControlOptionCommandR | keyCode=0x0F, mods=⌃⌥⌘ |
| HotkeyPreferencesTests | customBindingPersistsToUserDefaults | Custom binding saved and retrieved |
| HotkeyPreferencesTests | resetToDefaultRemovesCustomBinding | Reset restores default binding |
| HotkeyPreferencesTests | hotkeyBindingEquality | Equatable implementation correct |
| HotkeyPreferencesTests | hotkeyActionRawValues | Raw values match expected strings |
| HotkeyPreferencesTests | hotkeyActionAllCasesCount | Exactly 3 actions |
| HotkeyActionTests | approveNextRemovesFirstPendingApproval | First approval removed after action |
| HotkeyActionTests | rejectNextRemovesFirstPendingApproval | First approval removed after action |
| HotkeyActionTests | approveNextWithEmptyQueueDoesNothing | No error when queue empty |

### Verification Commands
```bash
swift build
swift test --filter HotkeyPreferencesTests
swift test --filter HotkeyActionTests
swift test  # All tests
```

---

## Execution Contract

```json
{
  "issue_ref": "HCS-008",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Services/HotkeyPreferences.swift",
      "function": "",
      "change_description": "CREATE new file with HotkeyAction enum, HotkeyBinding struct, HotkeyPreferences class for UserDefaults storage with default bindings for Control+Option+Command+H/A/R",
      "verification": "swift build succeeds; HotkeyPreferencesTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/HotkeyService.swift",
      "function": "",
      "change_description": "CREATE new file with HotkeyServiceProtocol, HotkeyService class using Carbon RegisterEventHotKey API for global hotkey registration with accessibility check",
      "verification": "swift build succeeds; hotkeys register when accessibility permission granted"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppDelegate.swift",
      "function": "applicationDidFinishLaunching, applicationWillTerminate",
      "change_description": "MODIFY to remove inline hotkey code (setupGlobalHotkey, cleanupHotkey, hotkeyHandler, fourCharCode), add hotkeyService property, initialize HotkeyService on launch, cleanup on terminate",
      "verification": "swift build succeeds; app launches with HotkeyService initialized"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppState.swift",
      "function": "approveNext, rejectNext",
      "change_description": "ADD two new async methods to approve/reject first pending item in queue via apiClient",
      "verification": "swift build succeeds; HotkeyActionTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/HeimdallApp.swift",
      "function": "wireHotkeys",
      "change_description": "ADD wireHotkeys() method to set handlers for toggleDashboard/approveNext/rejectNext actions and call registerHotkeys(); call from onAppear",
      "verification": "swift build succeeds; hotkey handlers connected to AppState methods"
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift",
      "function": "",
      "change_description": "CREATE new test file with HotkeyPreferencesTests suite (9 tests) and HotkeyActionTests suite (3 tests) testing persistence, defaults, reset, and action execution",
      "verification": "swift test passes all HotkeyPreferencesTests and HotkeyActionTests"
    }
  ]
}
```
