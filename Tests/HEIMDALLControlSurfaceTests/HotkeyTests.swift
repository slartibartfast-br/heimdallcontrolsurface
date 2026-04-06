// Tests/HEIMDALLControlSurfaceTests/HotkeyTests.swift
// HCS-008: Unit tests for hotkey configuration persistence

import Testing
import Foundation
@testable import HEIMDALLControlSurface

// MARK: - Hotkey Preferences Tests

@Suite("Hotkey Preferences Tests", .serialized)
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
        // Control + Option + Command = controlKey | optionKey | cmdKey
        let expected = UInt32(0x1000 | 0x0800 | 0x0100)
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

@Suite("Hotkey Binding Tests", .serialized)
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
