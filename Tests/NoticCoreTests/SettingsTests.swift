import Foundation
import Testing
import NoticCore

@Suite("Settings")
struct SettingsTests {
    @Test func `defaults keep Notic out of the Dock, off login, and below other apps`() throws {
        let workspace = try WorkspaceFixture().launch()

        #expect(workspace.settings.fontChoice == .handwriting)
        #expect(workspace.settings.showsDockIcon == false)
        #expect(workspace.settings.launchAtLogin == false)
        #expect(workspace.settings.showsAboveAllApps == false)
        #expect(workspace.settings.visibleOverFullScreenApps == false)
        #expect(workspace.settings.paperStyle == .pastel)
        #expect(workspace.settings.tiltsTabs == true)
    }

    @Test func `paper style and tab tilt are restored after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()

        workspace.updateSettings {
            $0.paperStyle = .adaptive
            $0.tiltsTabs = false
        }

        let relaunched = try fixture.launch()
        #expect(relaunched.settings.paperStyle == .adaptive)
        #expect(relaunched.settings.tiltsTabs == false)
    }

    @Test func `a settings file written before a preference existed still decodes with the default`() throws {
        let legacy = """
        {"fontChoice":"system","hasCreatedFirstNote":true,"launchAtLogin":false,"showsAboveAllApps":true,"showsDockIcon":false,"visibleOverFullScreenApps":false}
        """
        let settings = try JSONDecoder().decode(NoticSettings.self, from: Data(legacy.utf8))

        #expect(settings.fontChoice == .system)
        #expect(settings.showsAboveAllApps == true)
        #expect(settings.paperStyle == .pastel)
        #expect(settings.tiltsTabs == true)
    }

    @Test func `changed settings are restored after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()

        workspace.updateSettings {
            $0.fontChoice = .system
            $0.showsDockIcon = true
            $0.showsAboveAllApps = true
        }

        let relaunched = try fixture.launch()
        #expect(relaunched.settings.fontChoice == .system)
        #expect(relaunched.settings.showsDockIcon == true)
        #expect(relaunched.settings.showsAboveAllApps == true)
        #expect(relaunched.settings.launchAtLogin == false)
    }

    @Test func `the new deck and text preferences default to today's behaviour`() throws {
        let workspace = try WorkspaceFixture().launch()

        #expect(workspace.settings.textSize == 21)
        #expect(workspace.settings.openDelay == NoticTiming.hoverExpandDelay)
        #expect(workspace.settings.animationSpeed == .normal)
        #expect(workspace.settings.fanTrigger == .hover)
        #expect(workspace.settings.keepsDeckOpen == false)
    }

    @Test func `the new deck and text preferences are restored after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()

        workspace.updateSettings {
            $0.textSize = 28
            $0.openDelay = 0.3
            $0.animationSpeed = .slow
            $0.fanTrigger = .click
            $0.keepsDeckOpen = true
        }

        let relaunched = try fixture.launch()
        #expect(relaunched.settings.textSize == 28)
        #expect(relaunched.settings.openDelay == 0.3)
        #expect(relaunched.settings.animationSpeed == .slow)
        #expect(relaunched.settings.fanTrigger == .click)
        #expect(relaunched.settings.keepsDeckOpen == true)
    }

    @Test func `a settings file written before the deck preferences existed decodes with their defaults`() throws {
        let legacy = """
        {"fontChoice":"system","paperStyle":"adaptive","tiltsTabs":false,"hasCreatedFirstNote":true,"launchAtLogin":false,"showsAboveAllApps":true,"showsDockIcon":false,"visibleOverFullScreenApps":false}
        """
        let settings = try JSONDecoder().decode(NoticSettings.self, from: Data(legacy.utf8))

        #expect(settings.paperStyle == .adaptive)
        #expect(settings.textSize == 21)
        #expect(settings.openDelay == NoticTiming.hoverExpandDelay)
        #expect(settings.animationSpeed == .normal)
        #expect(settings.fanTrigger == .hover)
        #expect(settings.keepsDeckOpen == false)
    }

    @Test func `an unsupported text size or out-of-range open delay is clamped on decode`() throws {
        let hostile = """
        {"textSize":19,"openDelay":99}
        """
        let settings = try JSONDecoder().decode(NoticSettings.self, from: Data(hostile.utf8))

        #expect(settings.textSize == 18)
        #expect(settings.openDelay == 0.6)
    }

    @Test func `an unsupported text size or out-of-range open delay is clamped when set`() throws {
        let workspace = try WorkspaceFixture().launch()

        workspace.updateSettings {
            $0.textSize = 100
            $0.openDelay = -5
        }

        #expect(workspace.settings.textSize == 28)
        #expect(workspace.settings.openDelay == 0)
    }

    @Test func `a failed settings write is reported and retried like any other save`() throws {
        let fixture = try WorkspaceFixture()
        let (workspace, store) = try fixture.launchWithFailableStore(failingSettings: true)

        workspace.updateSettings { $0.fontChoice = .system }

        #expect(workspace.saveState == .failed("Disk unavailable"))
        #expect(workspace.settings.fontChoice == .system)
        #expect(try fixture.launch().settings.fontChoice == .handwriting)

        store.shouldFail = false
        fixture.scheduler.advance(by: 2)

        #expect(workspace.saveState == .saved)
        #expect(try fixture.launch().settings.fontChoice == .system)
    }

    @Test func `the first-note prompt shows until the first note is created, even after relaunch`() throws {
        let fixture = try WorkspaceFixture()
        let workspace = try fixture.launch()
        #expect(workspace.showsFirstNotePrompt)

        let id = workspace.createNote()
        #expect(!workspace.showsFirstNotePrompt)

        workspace.delete([id])
        fixture.scheduler.advance(by: 10)
        #expect(workspace.activeNotes.isEmpty)
        #expect(!workspace.showsFirstNotePrompt)
        #expect(!(try fixture.launch().showsFirstNotePrompt))
    }
}
