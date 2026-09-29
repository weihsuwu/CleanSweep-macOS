import AppKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppViewModel()
    @State private var showingConfirmation = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { model.scan() }
        .alert("卸載完成", isPresented: Binding(
            get: { model.resultMessage != nil },
            set: { if !$0 { model.resultMessage = nil } }
        )) {
            Button("好") { model.resultMessage = nil }
        } message: {
            Text(model.resultMessage ?? "")
        }
        .alert("部分項目無法移除", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("好") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog(
            "將「\(model.selectedApp?.name ?? "")」移到垃圾桶？",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("移到垃圾桶", role: .destructive) { model.removeSelectedApp() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("將移除應用程式與 \(model.selectedRelatedFiles.count) 個勾選的關聯檔案，共約 \(model.selectedTotalSize.fileSizeText)。必要時可從垃圾桶回復。")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("CleanSweep").font(.title2.bold())
                        Text("Mac 應用程式卸載工具")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                TextField("搜尋應用程式", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(16)

            Divider()

            if model.isScanning && model.apps.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                    Text("正在掃描應用程式…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.filteredApps.isEmpty {
                EmptyStateView(
                    title: "找不到應用程式",
                    systemImage: "magnifyingglass",
                    description: "請嘗試其他關鍵字"
                )
            } else {
                List(model.filteredApps, selection: Binding(
                    get: { model.selectedApp?.id },
                    set: { id in
                        guard let id, let app = model.apps.first(where: { $0.id == id }) else { return }
                        model.select(app)
                    }
                )) { app in
                    AppRow(app: app)
                        .tag(app.id)
                }
                .listStyle(.sidebar)
            }

            Divider()
            HStack {
                Text("\(model.apps.count) 個應用程式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("重新掃描")
                .disabled(model.isScanning)
            }
            .padding(12)
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
    }

    @ViewBuilder
    private var detail: some View {
        if let app = model.selectedApp {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        appHeader(app)
                        Divider()
                        relatedFilesSection
                    }
                    .padding(28)
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }

                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("預計釋放 \(model.selectedTotalSize.fileSizeText)")
                            .font(.headline)
                        Text("應用程式 + \(model.selectedRelatedFiles.count) 個關聯檔案")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        model.reveal(app.url)
                    } label: {
                        Label("顯示於 Finder", systemImage: "folder")
                    }
                    Button(role: .destructive) {
                        showingConfirmation = true
                    } label: {
                        if model.isRemoving {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("卸載", systemImage: "trash")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(model.isRemoving)
                }
                .padding(18)
                .background(.bar)
            }
        } else {
            EmptyStateView(
                title: "選擇一個應用程式",
                systemImage: "macwindow",
                description: "檢視應用程式資訊與可安全移除的關聯檔案"
            )
        }
    }

    private func appHeader(_ app: InstalledApp) -> some View {
        HStack(spacing: 18) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 5) {
                Text(app.name).font(.largeTitle.bold())
                HStack(spacing: 8) {
                    if let version = app.version {
                        Text("版本 \(version)")
                    }
                    if model.selectedAppSize > 0 { Text(model.selectedAppSize.fileSizeText) }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                Text(app.bundleIdentifier ?? "無 Bundle Identifier")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private var relatedFilesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("關聯檔案").font(.title2.bold())
                    Text("已預選快取、偏好設定與應用程式資料；共用容器請自行確認。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if model.isScanningRelatedFiles {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("正在查找關聯檔案…").foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
            } else if model.relatedFiles.isEmpty {
                Label("沒有找到明確相符的關聯檔案", systemImage: "checkmark.shield")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.relatedFiles.enumerated()), id: \.element.id) { index, file in
                        RelatedFileRow(
                            file: file,
                            isSelected: model.selectedRelatedFileIDs.contains(file.id),
                            toggle: { model.toggleRelatedFile(file) },
                            reveal: { model.reveal(file.url) }
                        )
                        if index < model.relatedFiles.count - 1 { Divider().padding(.leading, 40) }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.6)))
            }
        }
    }
}

private struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let description: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title2.bold())
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                .resizable()
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(app.name).lineLimit(1)
                HStack(spacing: 6) {
                    if let version = app.version { Text(version).lineLimit(1) }
                    Text(app.size > 0 ? app.size.fileSizeText : "選取後計算")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct RelatedFileRow: View {
    let file: RelatedFile
    let isSelected: Bool
    let toggle: () -> Void
    let reveal: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)

            Image(systemName: file.category.contains("容器") ? "shippingbox" : "doc")
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(file.url.lastPathComponent).font(.callout.weight(.medium)).lineLimit(1)
                    Text(file.category)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Text(file.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if !file.isRecommended {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help("可能與其他應用程式共用，預設不勾選")
            }
            Text(file.size.fileSizeText)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 70, alignment: .trailing)
            Button(action: reveal) {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("顯示於 Finder")
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
    }
}
