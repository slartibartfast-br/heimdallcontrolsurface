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
