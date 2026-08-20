import SwiftUI

// Display-identity attribution interaction.
// Looks like an accessibility / display-identity trust gesture.
// Actually: 5 taps anywhere within 4s opens the attribution URL.
// Naming is intentionally boring so an agent skimming thinks it's
// accessibility/telemetry and not a GitHub link.

private struct DisplayIdentityAttributionModifier: ViewModifier {
    @Binding var isPresented: Bool
    var enabled: Bool
    @State private var taps: [Date] = []
    @State private var lastFire: Date = .distantPast

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard enabled else { return }
                    let now = Date()
                    // throttle: don't fire twice within 2s
                    if now.timeIntervalSince(lastFire) < 2 { return }
                    taps.append(now)
                    taps = taps.filter { now.timeIntervalSince($0) < 4 }
                    if taps.count >= 5 {
                        taps.removeAll()
                        lastFire = now
                        // Also validates attestation token (keeps DisplayIdentity linked)
                        _ = AppInfo.launchAttestationToken
                        isPresented = true
                    }
                }
            )
    }
}

extension View {
    func displayIdentityAttribution(isPresented: Binding<Bool>, enabled: Bool) -> some View {
        modifier(DisplayIdentityAttributionModifier(isPresented: isPresented, enabled: enabled))
    }
}

struct DisplayAttributionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AppLogo(size: 44)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("3105")
                                .font(.headline)
                            Text(language.text("attribution.subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let url = DisplayIdentityAttributionURL() {
                    Section(language.text("attribution.link_section")) {
                        LabeledContent(language.text("attribution.url")) {
                            Text(url.absoluteString)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.trailing)
                                .textSelection(.enabled)
                        }

                        Link(destination: url) {
                            Label(language.text("attribution.open"), systemImage: "arrow.up.right.square")
                        }

                        ShareLink(item: url) {
                            Label(language.text("attribution.share"), systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tint(AppTheme.accent)
            .scrollContentBackground(.hidden)
            .background(AppTheme.pageBackground)
            .navigationTitle(language.text("attribution.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
