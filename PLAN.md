# PLAN: HCS-006 — Notification Service

## Preflight Checklist

### git status
```
On branch feat/AASF-672
Untracked files:
  (use "git add <file>..." to include in what will be committed)
	.mcp.json.heimdall-backup

nothing added to commit but untracked files present (use "git add" to track)
```

### git branch
```
+ feat/AASF-647
+ feat/AASF-671
* feat/AASF-672
+ main
```

### ls data/queue/
```
ls: /Users/maurizio/development/heimdall/hcs/.worktrees/aasf-672/data/queue/: No such file or directory
```
(No queue directory exists — this is a Swift project, no stale envelopes)

### Mandatory Rules from CLAUDE.md
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

| Action | File | Purpose |
|--------|------|---------|
| CREATE | `Sources/.../Services/NotificationService.swift` | UNUserNotificationCenter wrapper for macOS notifications |
| CREATE | `Sources/.../Services/NotificationCategory.swift` | Notification categories with approve/reject action buttons |
| CREATE | `Sources/.../Services/NotificationDelegate.swift` | Handle user responses from notification center actions |
| MODIFY | `Sources/.../AppState.swift` | Add escalation event storage and notification triggering |
| MODIFY | `Sources/.../AppDelegate.swift` | Initialize notification permissions on first launch |
| MODIFY | `Sources/.../Models/Event.swift` | Add `escalation` event type for notifications |
| MODIFY | `Tests/.../ServiceTests.swift` | Add NotificationService, category, and delegate tests |

---

## Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AppState                             │
│   @Published escalations: [EscalationEntry]                  │
│   func handleEscalation(event) → triggers notification       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   NotificationService                        │
│   - requestAuthorization()                                   │
│   - showEscalationNotification(escalation, issueId)          │
│   - registerCategories()                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┼────────────┐
        ▼            ▼            ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐
│ Category:    │ │ Category:    │ │ NotificationDelegate     │
│ escalation   │ │ verdict      │ │ UNUserNotificationCenter │
│ [Approve]    │ │ [View]       │ │ Delegate                 │
│ [Reject]     │ │              │ │ - didReceive response    │
└──────────────┘ └──────────────┘ └──────────────────────────┘
                                             │
                                             ▼
                                  ┌──────────────────────────┐
                                  │   HeimdallAPIClient      │
                                  │   approve() / reject()   │
                                  └──────────────────────────┘
```

### Data Path Trace

**Escalation Event Flow:**
1. `WebSocketService.receiveMessages()` (line 84-97) receives event
2. `WebSocketService.parseMessage()` (line 99-109) parses to `WebSocketEvent`
3. `ConnectionManager.handleEvent()` (line 165-167) forwards to `eventHandler`
4. `AppState.handleEvent()` (new) filters for `.escalation` or `.verdict` with `.escalate` outcome
5. `AppState.handleEscalation()` (new) stores escalation and calls `NotificationService.showEscalationNotification()`
6. User clicks action button in notification
7. `NotificationDelegate.userNotificationCenter(_:didReceive:)` (new) extracts action and issueId
8. `HeimdallAPIClient.approve()` or `reject()` (lines 112-120) posts decision

---

## Implementation Details

### 1. NotificationCategory.swift (CREATE)

**Purpose:** Define notification categories with action buttons.

```swift
// Sources/HEIMDALLControlSurface/Services/NotificationCategory.swift
// HCS-006: Notification categories for escalation actions

import UserNotifications

/// Notification category identifiers
public enum NotificationCategoryID: String {
    case escalation = "ESCALATION"
    case verdict = "VERDICT"
    case error = "ERROR"
}

/// Notification action identifiers
public enum NotificationActionID: String {
    case approve = "APPROVE_ACTION"
    case reject = "REJECT_ACTION"
    case view = "VIEW_ACTION"
    case dismiss = "DISMISS_ACTION"
}

/// Creates and registers notification categories
public struct NotificationCategories {
    /// Create escalation category with approve/reject buttons
    public static func escalationCategory() -> UNNotificationCategory {
        let approveAction = UNNotificationAction(
            identifier: NotificationActionID.approve.rawValue,
            title: "Approve",
            options: [.foreground]
        )
        let rejectAction = UNNotificationAction(
            identifier: NotificationActionID.reject.rawValue,
            title: "Reject",
            options: [.destructive, .foreground]
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.escalation.rawValue,
            actions: [approveAction, rejectAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
    }

    /// Create verdict category with view button
    public static func verdictCategory() -> UNNotificationCategory {
        let viewAction = UNNotificationAction(
            identifier: NotificationActionID.view.rawValue,
            title: "View Details",
            options: [.foreground]
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.verdict.rawValue,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
    }

    /// Create error category (dismiss only)
    public static func errorCategory() -> UNNotificationCategory {
        return UNNotificationCategory(
            identifier: NotificationCategoryID.error.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }

    /// All categories for registration
    public static func allCategories() -> Set<UNNotificationCategory> {
        [escalationCategory(), verdictCategory(), errorCategory()]
    }
}
```

**Line count:** ~50 lines (struct + 4 factory methods)

---

### 2. NotificationService.swift (CREATE)

**Purpose:** UNUserNotificationCenter wrapper for scheduling notifications.

```swift
// Sources/HEIMDALLControlSurface/Services/NotificationService.swift
// HCS-006: macOS notification service for escalation alerts

import Foundation
import UserNotifications

/// Protocol for notification service (enables mocking)
public protocol NotificationServiceProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func showEscalationNotification(issueId: String, gate: String, reason: String) async throws
    func showVerdictNotification(issueId: String, outcome: String, reason: String) async throws
    func showErrorNotification(title: String, message: String) async throws
    func registerCategories()
}

/// UNUserNotificationCenter-based notification service
public final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Register notification categories on init
    public func registerCategories() {
        center.setNotificationCategories(NotificationCategories.allCategories())
    }

    /// Request notification authorization
    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Show escalation notification with approve/reject actions
    public func showEscalationNotification(
        issueId: String,
        gate: String,
        reason: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Escalation Required"
        content.subtitle = "\(issueId) — \(gate) gate"
        content.body = reason
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.escalation.rawValue
        content.userInfo = ["issueId": issueId, "gate": gate]

        let request = UNNotificationRequest(
            identifier: "escalation-\(issueId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Immediate
        )
        try await center.add(request)
    }

    /// Show verdict notification with view action
    public func showVerdictNotification(
        issueId: String,
        outcome: String,
        reason: String
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Verdict: \(outcome.capitalized)"
        content.subtitle = issueId
        content.body = reason
        content.sound = .default
        content.categoryIdentifier = NotificationCategoryID.verdict.rawValue
        content.userInfo = ["issueId": issueId]

        let request = UNNotificationRequest(
            identifier: "verdict-\(issueId)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }

    /// Show error notification
    public func showErrorNotification(title: String, message: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .defaultCritical
        content.categoryIdentifier = NotificationCategoryID.error.rawValue

        let request = UNNotificationRequest(
            identifier: "error-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        try await center.add(request)
    }
}
```

**Line count:** ~75 lines total (class + 5 methods, each under 20 lines)

---

### 3. NotificationDelegate.swift (CREATE)

**Purpose:** Handle user responses from notification center.

```swift
// Sources/HEIMDALLControlSurface/Services/NotificationDelegate.swift
// HCS-006: UNUserNotificationCenter delegate for handling user actions

import Foundation
import UserNotifications

/// Protocol for notification response handling (enables testing)
public protocol NotificationResponseHandler: AnyObject, Sendable {
    @MainActor func handleApprove(issueId: String) async
    @MainActor func handleReject(issueId: String) async
    @MainActor func handleViewIssue(issueId: String)
}

/// UNUserNotificationCenter delegate for inline action handling
@MainActor
public final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    public weak var responseHandler: (any NotificationResponseHandler)?

    public override init() {
        super.init()
    }

    /// Handle user response to notification action
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let issueId = userInfo["issueId"] as? String ?? ""

        Task { @MainActor in
            await handleAction(response.actionIdentifier, issueId: issueId)
            completionHandler()
        }
    }

    /// Route action to appropriate handler
    private func handleAction(_ actionId: String, issueId: String) async {
        switch actionId {
        case NotificationActionID.approve.rawValue:
            await responseHandler?.handleApprove(issueId: issueId)
        case NotificationActionID.reject.rawValue:
            await responseHandler?.handleReject(issueId: issueId)
        case NotificationActionID.view.rawValue:
            responseHandler?.handleViewIssue(issueId: issueId)
        case UNNotificationDefaultActionIdentifier:
            // User clicked notification body — open dashboard
            responseHandler?.handleViewIssue(issueId: issueId)
        default:
            break
        }
    }

    /// Handle notification presentation while app is in foreground
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show notifications even when app is active
        completionHandler([.banner, .sound])
    }
}
```

**Line count:** ~55 lines (class + 3 methods, each under 25 lines)

---

### 4. AppState.swift (MODIFY)

**Current state:** 29 lines, simple observable with dashboard/connection state.

**Changes:**
- Add `escalations: [EscalationEntry]` property
- Add `notificationService` dependency
- Add `handleEscalation()` method
- Conform to `ConnectionEventHandler` protocol
- Conform to `NotificationResponseHandler` protocol

```swift
// Add to AppState.swift after line 17

    // Pending escalations requiring user action
    var escalations: [EscalationEntry] = []

    // Notification service (injected)
    private var notificationService: (any NotificationServiceProtocol)?
    private var apiClient: (any HeimdallAPIClientProtocol)?

    // Configure services (called from AppDelegate)
    func configure(
        notificationService: any NotificationServiceProtocol,
        apiClient: any HeimdallAPIClientProtocol
    ) {
        self.notificationService = notificationService
        self.apiClient = apiClient
    }

// Add new model for escalation tracking
public struct EscalationEntry: Identifiable, Sendable {
    public let id: String
    public let issueId: String
    public let gate: String
    public let reason: String
    public let timestamp: Date

    public init(issueId: String, gate: String, reason: String, timestamp: Date = Date()) {
        self.id = "\(issueId)-\(timestamp.timeIntervalSince1970)"
        self.issueId = issueId
        self.gate = gate
        self.reason = reason
        self.timestamp = timestamp
    }
}
```

**Add ConnectionEventHandler conformance:**
```swift
extension AppState: ConnectionEventHandler {
    @MainActor
    func handleEvent(_ event: WebSocketEvent) {
        switch event.type {
        case .verdict:
            handleVerdictEvent(event)
        default:
            break
        }
    }

    private func handleVerdictEvent(_ event: WebSocketEvent) {
        guard let payload = try? event.verdictPayload() else { return }
        if payload.verdict.outcome == .escalate {
            handleEscalation(verdict: payload.verdict)
        }
    }

    private func handleEscalation(verdict: VerdictEntry) {
        let entry = EscalationEntry(
            issueId: verdict.issueId,
            gate: verdict.gate,
            reason: verdict.reason,
            timestamp: verdict.timestamp
        )
        escalations.append(entry)
        Task {
            try? await notificationService?.showEscalationNotification(
                issueId: verdict.issueId,
                gate: verdict.gate,
                reason: verdict.reason
            )
        }
    }
}
```

**Add NotificationResponseHandler conformance:**
```swift
extension AppState: NotificationResponseHandler {
    @MainActor
    func handleApprove(issueId: String) async {
        do {
            _ = try await apiClient?.approve(id: issueId)
            escalations.removeAll { $0.issueId == issueId }
        } catch {
            lastError = "Approve failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    func handleReject(issueId: String) async {
        do {
            _ = try await apiClient?.reject(id: issueId, reason: nil)
            escalations.removeAll { $0.issueId == issueId }
        } catch {
            lastError = "Reject failed: \(error.localizedDescription)"
        }
    }

    @MainActor
    func handleViewIssue(issueId: String) {
        selectedProjectId = issueId  // Used to navigate dashboard
        isDashboardOpen = true
        NotificationCenter.default.post(name: .openDashboard, object: nil)
    }
}
```

**Projected line count:** ~75 lines total (original 29 + ~46 new lines split across extensions)

---

### 5. AppDelegate.swift (MODIFY)

**Current state:** 82 lines including C callback function.

**Changes:**
- Add `notificationDelegate` property
- Initialize notification permissions in `applicationDidFinishLaunching`
- Wire up NotificationDelegate to UNUserNotificationCenter

```swift
// Add after line 12 (after eventHandler property)

    /// Notification delegate for handling user actions
    private var notificationDelegate: NotificationDelegate?
    private var notificationService: NotificationService?

// Add to applicationDidFinishLaunching after line 18 (after setActivationPolicy)

        // Set up notifications
        setupNotifications()

// Add new method after setupGlobalHotkey()

    /// Set up notification service and request permission
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
```

**Projected line count:** ~95 lines (current 82 + 13 new lines)

---

### 6. Event.swift (MODIFY)

**Current state:** 207 lines — mostly Codable boilerplate.

**Changes:** Add `escalation` event type (1 line change).

```swift
// Modify line 14 to add escalation type
public enum EventType: String, Codable, Sendable {
    case factoryUpdate = "factory_update"
    case verdict = "verdict"
    case heartbeat = "heartbeat"
    case pipelineUpdate = "pipeline_update"
    case agentStatus = "agent_status"
    case escalation = "escalation"  // NEW: explicit escalation events
}
```

**Projected line count:** 208 lines (+1 line)

---

### 7. ServiceTests.swift (MODIFY)

**Current state:** 350 lines.

**Changes:** Add test suites for NotificationService, NotificationCategories, NotificationDelegate.

```swift
// MARK: - Mock Notification Service

final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var authorizationRequested: Bool = false
    var authorizationResult: Bool = true
    var escalationNotifications: [(issueId: String, gate: String, reason: String)] = []
    var verdictNotifications: [(issueId: String, outcome: String, reason: String)] = []
    var errorNotifications: [(title: String, message: String)] = []
    var categoriesRegistered: Bool = false

    func requestAuthorization() async throws -> Bool {
        authorizationRequested = true
        return authorizationResult
    }

    func showEscalationNotification(issueId: String, gate: String, reason: String) async throws {
        escalationNotifications.append((issueId, gate, reason))
    }

    func showVerdictNotification(issueId: String, outcome: String, reason: String) async throws {
        verdictNotifications.append((issueId, outcome, reason))
    }

    func showErrorNotification(title: String, message: String) async throws {
        errorNotifications.append((title, message))
    }

    func registerCategories() {
        categoriesRegistered = true
    }
}

// MARK: - Notification Category Tests

@Suite("Notification Category Tests")
struct NotificationCategoryTests {
    @Test func escalationCategoryHasApproveRejectActions() async throws {
        let category = NotificationCategories.escalationCategory()
        #expect(category.identifier == "ESCALATION")
        #expect(category.actions.count == 2)
        let actionIds = category.actions.map { $0.identifier }
        #expect(actionIds.contains("APPROVE_ACTION"))
        #expect(actionIds.contains("REJECT_ACTION"))
    }

    @Test func verdictCategoryHasViewAction() async throws {
        let category = NotificationCategories.verdictCategory()
        #expect(category.identifier == "VERDICT")
        #expect(category.actions.count == 1)
        #expect(category.actions.first?.identifier == "VIEW_ACTION")
    }

    @Test func errorCategoryHasNoActions() async throws {
        let category = NotificationCategories.errorCategory()
        #expect(category.identifier == "ERROR")
        #expect(category.actions.isEmpty)
    }

    @Test func allCategoriesReturnsThreeCategories() async throws {
        let categories = NotificationCategories.allCategories()
        #expect(categories.count == 3)
    }
}

// MARK: - Mock Response Handler

@MainActor
final class MockResponseHandler: NotificationResponseHandler {
    var approvedIds: [String] = []
    var rejectedIds: [String] = []
    var viewedIds: [String] = []

    func handleApprove(issueId: String) async {
        approvedIds.append(issueId)
    }

    func handleReject(issueId: String) async {
        rejectedIds.append(issueId)
    }

    func handleViewIssue(issueId: String) {
        viewedIds.append(issueId)
    }
}

// MARK: - Notification Delegate Tests

@Suite("Notification Delegate Tests")
struct NotificationDelegateTests {
    @Test @MainActor func delegateInitialization() async throws {
        let delegate = NotificationDelegate()
        #expect(delegate.responseHandler == nil)
    }
}

// MARK: - AppState Escalation Tests

@Suite("AppState Escalation Tests")
struct AppStateEscalationTests {
    @Test @MainActor func initialEscalationsEmpty() async throws {
        let appState = AppState()
        #expect(appState.escalations.isEmpty)
    }

    @Test @MainActor func escalationEntryIdGeneration() async throws {
        let entry = EscalationEntry(
            issueId: "AASF-123",
            gate: "review",
            reason: "Test reason"
        )
        #expect(entry.issueId == "AASF-123")
        #expect(entry.gate == "review")
        #expect(entry.id.hasPrefix("AASF-123-"))
    }
}
```

**Projected line count:** ~450 lines (current 350 + ~100 new test lines)

---

## Function Size Plan

| File | Function | Current Lines | Projected Lines | Helper Needed |
|------|----------|---------------|-----------------|---------------|
| AppState.swift | handleEvent | N/A (new) | 8 | No |
| AppState.swift | handleVerdictEvent | N/A (new) | 5 | No |
| AppState.swift | handleEscalation | N/A (new) | 14 | No |
| AppState.swift | handleApprove | N/A (new) | 9 | No |
| AppState.swift | handleReject | N/A (new) | 9 | No |
| AppDelegate.swift | setupNotifications | N/A (new) | 13 | No |
| NotificationDelegate.swift | userNotificationCenter(didReceive:) | N/A (new) | 12 | No |
| NotificationDelegate.swift | handleAction | N/A (new) | 15 | No |
| NotificationService.swift | showEscalationNotification | N/A (new) | 18 | No |

All functions remain under 50 lines.

---

## Test Strategy

### Test Files
- `Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift` (MODIFY)

### Test Cases

| Suite | Test | Verification |
|-------|------|--------------|
| NotificationCategoryTests | escalationCategoryHasApproveRejectActions | Category has ESCALATION id and 2 actions |
| NotificationCategoryTests | verdictCategoryHasViewAction | Category has VERDICT id and VIEW_ACTION |
| NotificationCategoryTests | errorCategoryHasNoActions | Category has ERROR id and no actions |
| NotificationCategoryTests | allCategoriesReturnsThreeCategories | Set contains 3 categories |
| NotificationDelegateTests | delegateInitialization | Delegate creates with nil handler |
| AppStateEscalationTests | initialEscalationsEmpty | AppState.escalations starts empty |
| AppStateEscalationTests | escalationEntryIdGeneration | Entry ID contains issueId prefix |

### Verification Command
```bash
swift test --filter HEIMDALLControlSurfaceTests
```

---

## Verification Plan

1. **Build succeeds:** `swift build` exits 0
2. **Tests pass:** `swift test` exits 0
3. **Category registration:** Verify `NotificationCategories.allCategories()` returns 3 categories
4. **Escalation handling:** Mock verdict event with `.escalate` outcome triggers notification
5. **Action routing:** NotificationDelegate routes approve/reject to handler
6. **Dashboard opens:** View action posts `.openDashboard` notification

---

## Execution Contract

```json
{
  "issue_ref": "HCS-006",
  "deliverables": [
    {
      "file": "Sources/HEIMDALLControlSurface/Services/NotificationCategory.swift",
      "function": "",
      "change_description": "CREATE: Notification categories with escalation/verdict/error identifiers and action buttons",
      "verification": "swift build succeeds; NotificationCategories.allCategories() returns 3 categories"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/NotificationService.swift",
      "function": "",
      "change_description": "CREATE: UNUserNotificationCenter wrapper with requestAuthorization(), showEscalationNotification(), showVerdictNotification(), showErrorNotification()",
      "verification": "swift build succeeds; MockNotificationService can substitute in tests"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Services/NotificationDelegate.swift",
      "function": "",
      "change_description": "CREATE: UNUserNotificationCenterDelegate with handleAction() routing to NotificationResponseHandler",
      "verification": "swift build succeeds; delegate routes actions to handler"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppState.swift",
      "function": "handleEvent, handleEscalation, handleApprove, handleReject, handleViewIssue",
      "change_description": "MODIFY: Add escalations array, conform to ConnectionEventHandler and NotificationResponseHandler protocols",
      "verification": "swift test AppStateEscalationTests pass"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/AppDelegate.swift",
      "function": "setupNotifications",
      "change_description": "MODIFY: Add setupNotifications() to applicationDidFinishLaunching, initialize NotificationService and delegate",
      "verification": "swift build succeeds; notification permission requested on launch"
    },
    {
      "file": "Sources/HEIMDALLControlSurface/Models/Event.swift",
      "function": "",
      "change_description": "MODIFY: Add .escalation case to EventType enum",
      "verification": "EventType.escalation.rawValue == \"escalation\""
    },
    {
      "file": "Tests/HEIMDALLControlSurfaceTests/ServiceTests.swift",
      "function": "",
      "change_description": "MODIFY: Add MockNotificationService, NotificationCategoryTests, NotificationDelegateTests, AppStateEscalationTests suites",
      "verification": "swift test --filter HEIMDALLControlSurfaceTests passes all tests"
    }
  ]
}
```
