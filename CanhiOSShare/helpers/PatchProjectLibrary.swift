import CryptoKit
import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    var id: UUID { summary.packageID }
}

private let localStorageMagic = Data("CHEATIOSPATCH\0".utf8)

enum PatchProjectLibrary {
    // Key derived from device UUID — files encrypted with this key cannot be used on other devices
    private static func storageKey() -> SymmetricKey {
        let keyMaterial = Data("3105LOCAL/v1/\(DeviceIdentity.current)".utf8)
        return SymmetricKey(data: SHA256.hash(data: keyMaterial))
    }

    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent(".DSWLib", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func migrateRemoveLegacyFiles(fileManager: FileManager = .default) {
        guard let root = try? packageRootURL(fileManager: fileManager),
              let urls = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) else { return }
        for url in urls where url.pathExtension.lowercased() == "cheatiosvip" {
            try? fileManager.removeItem(at: url)
        }
    }

    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        guard let root = try? packageRootURL(fileManager: fileManager),
              let urls = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
              ) else { return [] }

        var byID: [UUID: PatchLibraryItem] = [:]
        for url in urls where url.pathExtension.lowercased() == "dat" {
            do {
                let raw = (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data()
                let isLegacy = raw.prefix(localStorageMagic.count) == localStorageMagic
                let data = try readPackage(at: url)
                let summary = try PatchPackageCodec.inspect(data)
                let decoded: DecodedPatchPackage?
                if let contentKey = try PatchKeyStore.load(for: summary) {
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                } else if summary.isPasswordProtected {
                    decoded = nil
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }
                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url
                )
                byID[summary.packageID] = item
                // Migrate legacy plain files to device-encrypted format
                if isLegacy { try? save(data: data, projectName: "", existingURL: url) }
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent)")
            }
        }
        return byID.values.sorted {
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
        }
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize <= PatchPackageLimits.maximumPackageBytes else {
            throw PatchPackageError.sizeLimitExceeded
        }
        let raw = try Data(contentsOf: url, options: .mappedIfSafe)
        // Try device-specific decryption first (new format)
        if let box = try? AES.GCM.SealedBox(combined: raw),
           let decrypted = try? AES.GCM.open(box, using: storageKey()) {
            return decrypted
        }
        // Fall back to legacy plain format (pre-device-lock)
        if raw.prefix(localStorageMagic.count) == localStorageMagic {
            return raw
        }
        throw PatchPackageError.invalidPasswordOrCorruptedPackage
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard data.count <= PatchPackageLimits.maximumPackageBytes else {
            throw PatchPackageError.sizeLimitExceeded
        }
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            destination = root.appendingPathComponent(UUID().uuidString).appendingPathExtension("dat")
        }
        // Encrypt with device-specific key so file cannot be used on other devices
        guard let encrypted = try? AES.GCM.seal(data, using: storageKey()).combined else {
            throw PatchPackageError.invalidProject
        }
        try encrypted.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: item.packageURL.path) {
            try fileManager.removeItem(at: item.packageURL)
        }
        try? PatchKeyStore.delete(for: item.summary)
    }

}
