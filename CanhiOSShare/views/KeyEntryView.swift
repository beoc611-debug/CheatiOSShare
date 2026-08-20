import SwiftUI

/// The very first thing the app shows: nothing else is reachable until a valid key is redeemed.
struct KeyEntryView: View {
    @EnvironmentObject private var licenseGate: LicenseGateStore
    @Environment(\.appLanguage) private var language
    @State private var code = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            TechBackground()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 56)

                    AppLogo(size: 72)

                    VStack(spacing: 6) {
                        Text(language.text("license.title"))
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(language.text("license.subtitle"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    VStack(alignment: .leading, spacing: 10) {
                        TextField(language.text("license.placeholder"), text: $code)
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(14)
                            .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
                            )
                            .focused($isFocused)
                            .submitLabel(.go)
                            .onSubmit(submit)

                        if let errorMessage = licenseGate.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 28)

                    Button(action: submit) {
                        Group {
                            if isSubmitting {
                                ProgressView().tint(.black)
                            } else {
                                Text(language.text("license.activate"))
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(AppTheme.techGlow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 28)
                    .disabled(isSubmitting || code.trimmingCharacters(in: .whitespaces).isEmpty)

                    Spacer(minLength: 56)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Make By ©CheatiOSVip")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(.dark)
        .onAppear { isFocused = true }
    }

    private func submit() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSubmitting else { return }
        isSubmitting = true
        Task {
            _ = await licenseGate.redeem(code: trimmed)
            isSubmitting = false
        }
    }
}
