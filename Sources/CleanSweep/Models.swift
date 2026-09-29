import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let version: String?
    let path: String
    let size: Int64
    let modifiedAt: Date?

    var url: URL { URL(fileURLWithPath: path) }
}

struct RelatedFile: Identifiable, Hashable, Sendable {
    let id: String
    let path: String
    let size: Int64
    let category: String
    let isRecommended: Bool

    var url: URL { URL(fileURLWithPath: path) }
}

struct RemovalResult: Sendable {
    let removed: [String]
    let failures: [String]
}

extension Int64 {
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
