import Foundation
import SwiftUI

struct UIConfigItem: Decodable, Identifiable {
    let id: String
    let type: String        // "toggle" | "slider" | "segment" | "colorPicker"
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

    private enum CodingKeys: String, CodingKey {
        case id, type, label, icon, min, max, step, unit
        case color = "colorHex"
        case showIf, showIfVal
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

    private enum CodingKeys: String, CodingKey {
        case id, title, icon, items
        case color = "colorHex"
    }
}

private struct TabContainer: Decodable {
    let sections: [UIConfigSection]
}

struct UIConfig: Decodable {
    let esp: [UIConfigSection]
    let misc: [UIConfigSection]

    var isEmpty: Bool { esp.isEmpty && misc.isEmpty }

    static let empty = UIConfig(esp: [], misc: [])

    private enum CodingKeys: String, CodingKey {
        case espAim = "esp_aim"
        case misc
    }

    init(esp: [UIConfigSection], misc: [UIConfigSection]) {
        self.esp = esp
        self.misc = misc
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let espTab = try container.decodeIfPresent(TabContainer.self, forKey: .espAim)
        let miscTab = try container.decodeIfPresent(TabContainer.self, forKey: .misc)
        self.esp = espTab?.sections ?? []
        self.misc = miscTab?.sections ?? []
    }
}
