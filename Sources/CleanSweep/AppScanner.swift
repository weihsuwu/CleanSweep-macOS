import Foundation

enum AppScanner {
    private static let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .contentModificationDateKey
    ]

    static func scanApplications() -> [InstalledApp] {
        let fm = FileManager.default
        let homeApplications = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        let roots = [URL(fileURLWithPath: "/Applications", isDirectory: true), homeApplications]
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for root in roots where fm.fileExists(atPath: root.path) {
            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            ) else { continue }

            for url in contents where url.pathExtension.lowercased() == "app" {
                let standardizedPath = url.standardizedFileURL.path
                guard seen.insert(standardizedPath).inserted else { continue }
                let bundle = Bundle(url: url)
                let values = try? url.resourceValues(forKeys: resourceKeys)
                let displayName = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                    ?? url.deletingPathExtension().lastPathComponent
                let version = (bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
                    ?? (bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String)

                apps.append(InstalledApp(
                    id: standardizedPath,
                    name: displayName,
                    bundleIdentifier: bundle?.bundleIdentifier,
                    version: version,
                    path: standardizedPath,
                    size: Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0),
                    modifiedAt: values?.contentModificationDate
                ))
            }
        }

        return apps.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func findRelatedFiles(for app: InstalledApp) -> [RelatedFile] {
        let fm = FileManager.default
        let library = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        let identifiers = searchIdentifiers(for: app)
        let candidates: [(String, String, Bool)] = [
            ("Application Support", "應用程式資料", true),
            ("Caches", "快取", true),
            ("Preferences", "偏好設定", true),
            ("Logs", "記錄檔", true),
            ("Saved Application State", "儲存狀態", true),
            ("HTTPStorages", "網路儲存", true),
            ("WebKit", "WebKit 資料", true),
            ("Containers", "沙盒容器", false),
            ("Group Containers", "共用容器", false)
        ]

        var matches: [RelatedFile] = []
        var seen = Set<String>()

        for (relativePath, category, recommended) in candidates {
            let folder = library.appendingPathComponent(relativePath, isDirectory: true)
            guard let children = try? fm.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children where matchesIdentifier(child.lastPathComponent, identifiers: identifiers) {
                let path = child.standardizedFileURL.path
                guard seen.insert(path).inserted else { continue }
                matches.append(RelatedFile(
                    id: path,
                    path: path,
                    size: directorySize(at: child),
                    category: category,
                    isRecommended: recommended
                ))
            }
        }

        return matches.sorted {
            if $0.isRecommended != $1.isRecommended { return $0.isRecommended && !$1.isRecommended }
            return $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let values = try? url.resourceValues(forKeys: resourceKeys) else { return 0 }
        if values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let fileValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  fileValues.isDirectory != true else { continue }
            total += Int64(fileValues.totalFileAllocatedSize ?? fileValues.fileAllocatedSize ?? 0)
        }
        return total
    }

    private static func searchIdentifiers(for app: InstalledApp) -> [String] {
        var values = [app.name, app.url.deletingPathExtension().lastPathComponent]
        if let bundleIdentifier = app.bundleIdentifier { values.append(bundleIdentifier) }
        return values
            .map { $0.lowercased().replacingOccurrences(of: " ", with: "") }
            .filter { $0.count >= 3 }
    }

    private static func matchesIdentifier(_ fileName: String, identifiers: [String]) -> Bool {
        let normalized = fileName.lowercased().replacingOccurrences(of: " ", with: "")
        return identifiers.contains { identifier in
            normalized == identifier
                || normalized == identifier + ".plist"
                || normalized.hasPrefix(identifier + ".")
                || normalized.hasSuffix("." + identifier)
        }
    }
}
