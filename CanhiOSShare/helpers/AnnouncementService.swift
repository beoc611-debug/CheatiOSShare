import Foundation

struct Announcement: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let linkLabel: String
    let linkURL: String
    let link2Label: String
    let link2URL: String
}

struct MaintenanceNotice: Equatable {
    let title: String
    let message: String
    let link1Label: String
    let link1URL: String
    let link2Label: String
    let link2URL: String
}

enum RemoteNoticeState: Equatable {
    case none
    case maintenance(MaintenanceNotice)
    case announcement(Announcement)
}

private struct AnnouncementResponse: Decodable {
    let enabled: Bool
    let maintenance: Bool?
    let id: String?
    let title: String?
    let message: String?
    let linkLabel: String?
    let linkURL: String?
    let maintenanceTitle: String?
    let maintenanceMessage: String?
    let maintenanceLink1Label: String?
    let maintenanceLink1URL: String?
    let maintenanceLink2Label: String?
    let maintenanceLink2URL: String?
}

enum AnnouncementService {
    static func fetchState() async -> RemoteNoticeState {
        var components = URLComponents(
            url: PatchHubService.baseURL.appendingPathComponent(PatchHubService.pathNotice),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "build", value: String(AppInfo.buildNumber))]
        guard let url = components.url else { return .none }
        var request = URLRequest(url: url)
        request.setValue(PatchHubService.clientToken, forHTTPHeaderField: "X-App-Token")
        request.setValue(DeviceIdentity.current, forHTTPHeaderField: "X-Device-Id")
        guard let (data, response) = try? await PinnedSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(AnnouncementResponse.self, from: data)
        else {
            return .none
        }

        if decoded.maintenance == true {
            return .maintenance(
                MaintenanceNotice(
                    title: decoded.maintenanceTitle ?? "",
                    message: decoded.maintenanceMessage ?? "",
                    link1Label: decoded.maintenanceLink1Label ?? "",
                    link1URL: decoded.maintenanceLink1URL ?? "",
                    link2Label: decoded.maintenanceLink2Label ?? "",
                    link2URL: decoded.maintenanceLink2URL ?? ""
                )
            )
        }
        guard decoded.enabled, let id = decoded.id else { return .none }
        return .announcement(
            Announcement(
                id: id,
                title: decoded.title ?? "",
                message: decoded.message ?? "",
                linkLabel: decoded.linkLabel ?? "",
                linkURL: decoded.linkURL ?? "",
                link2Label: decoded.maintenanceLink2Label ?? "",
                link2URL: decoded.maintenanceLink2URL ?? ""
            )
        )
    }
}
