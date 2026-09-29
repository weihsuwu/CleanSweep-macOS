import AppKit
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?
    @Published var relatedFiles: [RelatedFile] = []
    @Published var selectedRelatedFileIDs = Set<String>()
    @Published var selectedAppSize: Int64 = 0
    @Published var searchText = ""
    @Published var isScanning = false
    @Published var isScanningRelatedFiles = false
    @Published var isRemoving = false
    @Published var resultMessage: String?
    @Published var errorMessage: String?

    var filteredApps: [InstalledApp] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var selectedRelatedFiles: [RelatedFile] {
        relatedFiles.filter { selectedRelatedFileIDs.contains($0.id) }
    }

    var selectedTotalSize: Int64 {
        selectedAppSize + selectedRelatedFiles.reduce(0) { $0 + $1.size }
    }

    func scan() {
        isScanning = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                AppScanner.scanApplications()
            }.value
            apps = result
            isScanning = false
            if let selectedApp, !apps.contains(selectedApp) {
                self.selectedApp = nil
                relatedFiles = []
            }
        }
    }

    func select(_ app: InstalledApp) {
        selectedApp = app
        selectedAppSize = app.size
        relatedFiles = []
        selectedRelatedFileIDs = []
        isScanningRelatedFiles = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                (
                    files: AppScanner.findRelatedFiles(for: app),
                    appSize: AppScanner.directorySize(at: app.url)
                )
            }.value
            guard selectedApp?.id == app.id else { return }
            relatedFiles = result.files
            selectedAppSize = result.appSize
            selectedRelatedFileIDs = Set(result.files.filter(\.isRecommended).map(\.id))
            isScanningRelatedFiles = false
        }
    }

    func toggleRelatedFile(_ file: RelatedFile) {
        if selectedRelatedFileIDs.contains(file.id) {
            selectedRelatedFileIDs.remove(file.id)
        } else {
            selectedRelatedFileIDs.insert(file.id)
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func removeSelectedApp() {
        guard let app = selectedApp else { return }
        let urls = [app.url] + selectedRelatedFiles.map(\.url)
        isRemoving = true

        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.moveToTrash(urls)
            }.value
            isRemoving = false

            if result.failures.isEmpty {
                resultMessage = "已將 \(app.name) 與 \(max(0, result.removed.count - 1)) 個關聯檔案移到垃圾桶。"
                selectedApp = nil
                selectedAppSize = 0
                relatedFiles = []
                selectedRelatedFileIDs = []
                scan()
            } else {
                let succeeded = result.removed.count
                errorMessage = "已移除 \(succeeded) 個項目，但有 \(result.failures.count) 個失敗：\n\n" + result.failures.joined(separator: "\n")
                scan()
            }
        }
    }

    nonisolated private static func moveToTrash(_ urls: [URL]) -> RemovalResult {
        var removed: [String] = []
        var failures: [String] = []
        let fm = FileManager.default

        for url in urls {
            guard fm.fileExists(atPath: url.path) else { continue }
            do {
                var resultingURL: NSURL?
                try fm.trashItem(at: url, resultingItemURL: &resultingURL)
                removed.append(url.path)
            } catch {
                failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
            }
        }
        return RemovalResult(removed: removed, failures: failures)
    }
}
