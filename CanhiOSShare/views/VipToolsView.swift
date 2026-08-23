import SwiftUI

struct VipToolsView: View {
    var body: some View {
        ZStack {
            TechBackground()

            ScrollView {
                VStack(spacing: 0) {
                    header
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)

                    toolsGrid
                        .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.neonPurple.opacity(0.30), AppTheme.techGlow.opacity(0.15)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.neonPurple.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.techGlow, AppTheme.neonPurple],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Vip Tools")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.55, blue: 1.00),
                                     Color(red: 0.48, green: 0.37, blue: 1.00)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                Text("Công cụ cao cấp · Độc quyền VIP")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(red: 0.54, green: 0.62, blue: 0.78))
            }

            Spacer()
        }
    }

    // MARK: - Grid

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var toolsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 14) {
            ForEach(VipTool.allTools) { tool in
                VipToolCard(tool: tool)
            }
        }
    }
}

// MARK: - Model

struct VipTool: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    let action: (() -> Void)?

    static let allTools: [VipTool] = [
        VipTool(
            icon: "shazam.logo.fill",
            title: "Sắp ra mắt",
            subtitle: "Đang phát triển",
            gradient: [Color(red: 0.26, green: 0.55, blue: 1.00), Color(red: 0.16, green: 0.35, blue: 0.80)],
            action: nil
        ),
        VipTool(
            icon: "lock.shield.fill",
            title: "Sắp ra mắt",
            subtitle: "Đang phát triển",
            gradient: [Color(red: 0.48, green: 0.37, blue: 1.00), Color(red: 0.28, green: 0.17, blue: 0.80)],
            action: nil
        ),
        VipTool(
            icon: "bolt.shield.fill",
            title: "Sắp ra mắt",
            subtitle: "Đang phát triển",
            gradient: [Color(red: 0.10, green: 0.55, blue: 0.80), Color(red: 0.06, green: 0.35, blue: 0.60)],
            action: nil
        ),
        VipTool(
            icon: "cpu.fill",
            title: "Sắp ra mắt",
            subtitle: "Đang phát triển",
            gradient: [Color(red: 0.55, green: 0.20, blue: 0.80), Color(red: 0.35, green: 0.10, blue: 0.60)],
            action: nil
        ),
    ]
}

// MARK: - Card

struct VipToolCard: View {
    let tool: VipTool

    var body: some View {
        Button {
            tool.action?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(colors: tool.gradient.map { $0.opacity(0.25) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: tool.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: tool.gradient,
                                           startPoint: .top, endPoint: .bottom)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(tool.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(Color(red: 0.50, green: 0.58, blue: 0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(red: 0.40, green: 0.48, blue: 0.65))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.88))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [tool.gradient[0].opacity(0.40), tool.gradient[1].opacity(0.15)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(tool.action == nil ? 0.60 : 1.0)
    }
}
