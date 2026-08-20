import Foundation

struct FileEntry: Identifiable, Hashable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let isSymlink: Bool

    var id: String { path }

    var sizeText: String {
        if isDirectory || isSymlink { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var icon: String {
        if isSymlink  { return "arrow.triangle.branch" }
        if isDirectory { return "folder.fill" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return "photo"
        case "mp4", "mov", "m4v": return "film"
        case "mp3", "aac", "m4a", "wav", "flac": return "music.note"
        case "pdf": return "doc.richtext"
        case "zip", "ipa", "tipa", "deb", "tar", "gz": return "archivebox"
        case "plist": return "list.bullet.rectangle"
        case "db", "sqlite", "sqlite3": return "cylinder"
        case "txt", "log": return "doc.text"
        default: return "doc"
        }
    }
}

enum ContainerStore {
    static func listFiles(at path: String) -> [FileEntry] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        return items.compactMap { name -> FileEntry? in
            let full = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            var lstat_buf = stat()
            guard lstat(full, &lstat_buf) == 0 else { return nil }
            let isLink = (lstat_buf.st_mode & S_IFMT) == S_IFLNK
            fm.fileExists(atPath: full, isDirectory: &isDir)
            let size = isDir.boolValue ? 0 : Int64(lstat_buf.st_size)
            return FileEntry(name: name, path: full,
                             isDirectory: isDir.boolValue,
                             size: size, isSymlink: isLink)
        }
        .sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func readTextFile(at path: String, limit: Int = 300_000) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return "Không thể đọc file."
        }
        let slice = data.prefix(limit)
        if let text = String(data: slice, encoding: .utf8) {
            return data.count > limit ? text + "\n… [đã cắt bớt]" : text
        }
        if let text = String(data: slice, encoding: .utf16) {
            return data.count > limit ? text + "\n… [đã cắt bớt]" : text
        }
        return "Dữ liệu nhị phân (\(data.count) bytes) — không phải text."
    }

    static func appContainerPath(for bundleID: String) -> String? {
        var error: NSString?
        return MCMFilzaDataContainerPath(bundleID, &error)
    }

    static func canDelete(at path: String) -> Bool {
        access(path, W_OK) == 0
    }

    static func deleteItem(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }

    static func moveItem(from source: String, to destination: String) throws {
        try FileManager.default.moveItem(atPath: source, toPath: destination)
    }

    static func copyItem(from source: String, to destination: String) throws {
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }
}
