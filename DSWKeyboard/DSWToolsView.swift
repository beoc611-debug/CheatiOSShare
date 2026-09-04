import SwiftUI
import UIKit

// MARK: - Tool model

struct DSWTool: Identifiable {
    let id: String
    let name: String
    let icon: String
    let dual: Bool
    let label1: String
    let label2: String

    init(_ id: String, _ name: String, _ icon: String,
         dual: Bool = false, label1: String = "ID Game", label2: String = "ID Game") {
        self.id = id; self.name = name; self.icon = icon
        self.dual = dual; self.label1 = label1; self.label2 = label2
    }
}

private let tools: [DSWTool] = [
    DSWTool("spam_invite", "Spam Kết Bạn", "person.2.fill"),
    DSWTool("team_dance",  "Múa Hành Động", "figure.walk", dual: true, label1: "Team Code", label2: "ID Game"),
    DSWTool("team5",       "Tạo Tổ Đội 5", "person.3.fill"),
    DSWTool("spam_music",  "Spam Nhạc",    "music.note", label1: "Team Code / ID"),
    DSWTool("buff_like",   "Buff Like",    "hand.thumbsup.fill"),
]

private let kbSecret  = "dswkb_X3mP9rVn8qK"
private let baseURL   = "https://patches.cheatiosvip.net/cv/kbpx"

// MARK: - Main View

struct DSWToolsView: View {
    let controller: UIInputViewController

    @State private var selected: DSWTool? = nil
    @State private var field1   = ""
    @State private var field2   = ""
    @State private var result   = ""
    @State private var loading  = false
    @State private var resultOk = true

    // colours
    private let bg      = Color(red: 0.10, green: 0.10, blue: 0.12)
    private let card    = Color(red: 0.17, green: 0.17, blue: 0.20)
    private let accent  = Color(red: 0.20, green: 0.50, blue: 1.00)
    private let dimText = Color(red: 0.55, green: 0.55, blue: 0.60)

    var body: some View {
        VStack(spacing: 0) {
            header
            toolStrip
            if selected != nil {
                inputArea
            }
        }
        .background(bg)
        .frame(maxWidth: .infinity)
    }

    // MARK: Header bar
    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .foregroundColor(accent)
                .font(.system(size: 14, weight: .semibold))
            Text("DSW Tools")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: { controller.advanceToNextInputMode() }) {
                Image(systemName: "globe")
                    .font(.system(size: 16))
                    .foregroundColor(dimText)
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(red: 0.13, green: 0.13, blue: 0.16))
    }

    // MARK: Tool strip
    private var toolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tools) { tool in
                    toolButton(tool)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(card)
    }

    private func toolButton(_ tool: DSWTool) -> some View {
        let isSelected = selected?.id == tool.id
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selected = tool
                field1 = ""; field2 = ""; result = ""
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? .white : dimText)
                Text(tool.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : dimText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 70, height: 56)
            .background(isSelected ? accent : Color(red: 0.22, green: 0.22, blue: 0.26))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
        }
    }

    // MARK: Input + run + result
    private var inputArea: some View {
        VStack(spacing: 10) {
            if let tool = selected {
                inputRow(label: tool.label1, text: $field1)
                if tool.dual {
                    inputRow(label: tool.label2, text: $field2)
                }
            }

            runButton

            if !result.isEmpty {
                resultBubble
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(bg)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func inputRow(label: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(dimText)
                .frame(width: 86, alignment: .leading)
            TextField("", text: text)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .keyboardType(.numberPad)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(card)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var runButton: some View {
        let canRun = !loading && !field1.isEmpty && (selected?.dual == false || !field2.isEmpty)
        return Button(action: runTool) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView()
                        .scaleEffect(0.75)
                        .tint(.white)
                }
                Text(loading ? "Đang chạy…" : "▶  Chạy")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(canRun ? accent : Color.gray.opacity(0.4))
            .cornerRadius(10)
        }
        .disabled(!canRun)
    }

    private var resultBubble: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: resultOk ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(resultOk ? .green : .red)
                .font(.system(size: 14))
            Text(result)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(resultOk ? Color(red: 0.5, green: 1.0, blue: 0.5) : Color(red: 1, green: 0.4, blue: 0.4))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(card)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((resultOk ? Color.green : Color.red).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: API call
    private func runTool() {
        guard let tool = selected, !field1.isEmpty else { return }
        loading = true; result = ""

        let enc: (String) -> String = { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }

        var urlStr: String
        if tool.dual {
            urlStr = "\(baseURL)/\(tool.id)?tc=\(enc(field1))&uid=\(enc(field2))"
        } else {
            urlStr = "\(baseURL)/\(tool.id)?uid=\(enc(field1))"
        }

        guard let url = URL(string: urlStr) else { loading = false; return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.setValue(kbSecret, forHTTPHeaderField: "x-kb-secret")

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                loading = false
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if let error = error {
                    resultOk = false
                    result = error.localizedDescription
                    return
                }
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                resultOk = status == 200
                result = "[\(status)] \(body)"
            }
        }.resume()
    }
}
