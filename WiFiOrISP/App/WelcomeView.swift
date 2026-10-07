import ServiceManagement
import SwiftUI

/// Shown once, on first launch: what the menu bar icon means, and the two choices
/// worth making up front (the network name and opening at login).
struct WelcomeView: View {
    @ObservedObject var location: LocationAccess
    let done: () -> Void
    @State private var openAtLogin = true

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("WiFi or ISP is in your menu bar").font(.title2.bold())
                    Text("It checks your router and the internet every few seconds, and tells you which side is slow.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: RouterIcon.menuBarImage(.bars(3)))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text("The lights on the little router show your Wi-Fi signal. When something's slow, a word appears "
                    + "next to it, like **ISP** or **WiFi**. Click it for the details.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Show your Wi-Fi network's name").font(.headline)
                    Text("macOS treats network names as location data, so the app needs Location access to show yours. "
                        + "It never asks where you are, and everything else works without it.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if location.isAuthorized {
                        Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button(location.status == .denied ? "Open System Settings…" : "Allow Location Access…") {
                            location.request()
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle("Open WiFi or ISP at login", isOn: $openAtLogin)

            HStack {
                Spacer()
                Button("Done") {
                    if openAtLogin {
                        try? SMAppService.mainApp.register()
                    }
                    done()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
