# CleanSweep

CleanSweep 是一個以 SwiftUI 開發的 macOS 應用程式卸載工具。它會掃描已安裝的 App，並尋找位於使用者 `~/Library` 中的關聯資料。

## 功能

- 掃描 `/Applications` 與 `~/Applications`
- 顯示 App 圖示、版本、Bundle ID 與磁碟用量
- 搜尋名稱或 Bundle ID
- 尋找快取、偏好設定、記錄檔、Application Support 等關聯檔案
- 沙盒與共用容器預設不勾選，避免誤刪共用資料
- 卸載前再次確認，所有項目只會移到垃圾桶

## 執行

需要 macOS 13 以上與 Xcode Command Line Tools。

```bash
swift run CleanSweep
```

若要建立可直接雙擊的 App：

```bash
./scripts/build-app.sh
open dist/CleanSweep.app
```

完成品會位於 `dist/CleanSweep.app`。此為本機開發簽署版，若要公開分發，還需使用 Apple Developer ID 簽署與公證。

## 測試

```bash
swift test
```

## 安全說明

CleanSweep 不會永久刪除檔案。對於系統保護或需要管理員權限的 App，第一版會顯示錯誤，不會嘗試繞過 macOS 安全機制。
