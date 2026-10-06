import ServiceManagement
import SwiftUI
import WiFiOrISPCore

struct GeneralSettingsView: View {
    let updater: Updater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var checksAutomatically: Bool
    @AppStorage(Preferences.Keys.showsSignalInMenuBar) private var showsSignal = false
    @AppStorage(Preferences.Keys.showsVerdictInMenuBar) private var showsVerdict = true

    init(updater: Updater) {
        self.updater = updater
        _checksAutomatically = State(initialValue: updater.checksAutomatically)
    }

    var body: some View {
        Form {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Section("Menu bar") {
                Toggle("Show signal strength as a number", isOn: $showsSignal)
                    .help("dBm is the unit radios use: −30 is as strong as it gets, −80 barely works.")
                Toggle("Show which side is slow (WiFi, Router, or ISP)", isOn: $showsVerdict)
            }
            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $checksAutomatically)
                    .onChange(of: checksAutomatically) { _, value in updater.checksAutomatically = value }
            }
        }
        .formStyle(.grouped)
    }
}

struct AlertsSettingsView: View {
    @AppStorage(Preferences.key(for: .drop)) private var drop = true
    @AppStorage(Preferences.key(for: .fellTo24GHz)) private var band = true
    @AppStorage(Preferences.key(for: .roamedWeaker)) private var roam = true

    var body: some View {
        Form {
            Section {
                Toggle("The internet drops, and when it's back", isOn: $drop)
                Toggle("Your Mac falls back to 2.4 GHz", isOn: $band)
                Toggle("Your Mac roams to a weaker access point", isOn: $roam)
            } header: {
                Text("Notify me when")
            } footer: {
                Text("Alerts repeat at most every five minutes. "
                    + "Drops while your Mac reconnects after sleep don't count.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsView: View {
    @ObservedObject var location: LocationAccess
    let store: LogStore
    @AppStorage(Preferences.Keys.keepDays) private var keepDays = LogStore.defaultKeepDays
    @State private var confirmingDelete = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Location access", value: location.statusText)
                Text(LocationAccess.explanation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !location.isAuthorized {
                    Button(location.status == .denied ? "Open System Settings…" : "Show Network Name…") {
                        location.requestWithExplanation()
                    }
                }
            } header: {
                Text("Network name")
            }
            Section {
                Picker("Keep history for", selection: $keepDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
                .onChange(of: keepDays) { _, days in store.prune(keepingDays: days) }
                Button("Delete History…", role: .destructive) { confirmingDelete = true }
                    .confirmationDialog("Delete all measurements and events?", isPresented: $confirmingDelete) {
                        Button("Delete History", role: .destructive) { store.deleteAll() }
                    }
            } header: {
                Text("History")
            } footer: {
                Text("History stays on this Mac. The app has no analytics and sends nothing anywhere, "
                    + "except the speed and lag tests you start yourself.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage(Preferences.Keys.responsivenessServer)
    private var server = ResponsivenessTest.defaultConfigURL.absoluteString

    var body: some View {
        Form {
            Section {
                TextField("Server configuration URL", text: $server)
                    .textFieldStyle(.roundedBorder)
                Button("Use Cloudflare's Server") { server = ResponsivenessTest.defaultConfigURL.absoluteString }
                    .disabled(server == ResponsivenessTest.defaultConfigURL.absoluteString)
            } header: {
                Text("Lag under load server")
            } footer: {
                Text("Any server that implements the IETF responsiveness test works, including one you host yourself "
                    + "with github.com/network-quality/goserver.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
