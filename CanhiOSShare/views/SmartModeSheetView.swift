import SwiftUI

/// The short (not full-height) sheet opened by holding the gear icon ~3s: a toggle for the
/// floating quick-access gear, and — once on — which game it should open.
struct SmartModeSheetView: View {
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SmartModeStore
    let games: [RemoteGameSummary]
    var onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(language.text("smart_mode.title"))
                    .font(.headline.weight(.bold))
                Text(language.text("smart_mode.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            toggleRow

            if store.isEnabled {
                gamePicker
                    .transition(.opacity)
            }

            Button {
                onChange()
                dismiss()
            } label: {
                Text(language.text("common.done"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .background(AppTheme.techGlow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .animation(.easeInOut(duration: 0.2), value: store.isEnabled)
        .background(TechBackground())
        .presentationDetents([.height(store.isEnabled ? 420 : 250)])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .onAppear {
            if store.selectedGameID == nil {
                store.selectedGameID = games.first?.id
            }
        }
    }

    private var toggleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("smart_mode.toggle_title"))
                    .font(.subheadline.weight(.semibold))
                Text(language.text("smart_mode.toggle_subtitle"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $store.isEnabled)
                .labelsHidden()
                .tint(AppTheme.techGlow)
        }
        .padding(14)
        .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
        )
    }

    private var gamePicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(language.text("smart_mode.pick_game"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)

            if games.isEmpty {
                Text(language.text("patch.no_games_yet"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            } else {
                ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                    gameRow(game)
                    if index != games.count - 1 {
                        Divider()
                            .overlay(Color.white.opacity(0.06))
                            .padding(.leading, 14)
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.techCardStroke, lineWidth: 1)
        )
    }

    private func gameRow(_ game: RemoteGameSummary) -> some View {
        let isSelected = store.selectedGameID == game.id
        return Button {
            store.selectedGameID = game.id
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(isSelected ? AppTheme.techGlow : Color.white.opacity(0.28), lineWidth: 1.5)
                    .background(Circle().fill(isSelected ? AppTheme.techGlow : .clear))
                    .frame(width: 16, height: 16)
                Text(game.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
