import Foundation
import SwiftUI

struct UIConfigItem: Decodable, Identifiable {
    let id: String
    let type: String        // "toggle" | "slider"
    let label: String
    let icon: String        // SF Symbol
    let color: String       // hex without #
    let showIf: String?     // id of toggle that controls visibility
    let showIfVal: String?  // expected value ("true"/"false")
    let min: Double?
    let max: Double?
    let step: Double?
    let unit: String?

    var accentColor: Color {
        Color(hex: color) ?? Color(red: 1, green: 0.18, blue: 0.38)
    }
}

struct UIConfigSection: Decodable, Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: String
    let items: [UIConfigItem]

    var accentColor: Color {
        Color(hex: color) ?? Color(red: 1, green: 0.18, blue: 0.38)
    }
}

struct UIConfig: Decodable {
    let esp: [UIConfigSection]
    let misc: [UIConfigSection]

    var isEmpty: Bool { esp.isEmpty && misc.isEmpty }

    static let empty = UIConfig(esp: [], misc: [])
}
