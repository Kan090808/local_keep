# iOS 媒體檢視器更新

## 更新日期
2025年10月11日

## 更新內容

### 問題描述
之前在 iPhone 上開啟圖片和影片時，會使用應用內的預覽功能 (`UIDocumentInteractionController.presentPreview()`)，無法使用系統的瀏覽器或相簿應用開啟。

### 解決方案
修改了 iOS 的原生代碼 (`ios/Runner/AppDelegate.swift`)，實現以下功能：

1. **自動檢測檔案類型**
   - 圖片格式：jpg, jpeg, png, gif, bmp, heic, heif, webp
   - 影片格式：mp4, mov, m4v, avi, mkv, wmv, flv, webm

2. **智能開啟方式**
   - **圖片和影片**：使用 `UIApplication.shared.open()` 直接用系統預設應用開啟
   - **其他檔案類型**：繼續使用應用內預覽 (`UIDocumentInteractionController`)

3. **後備方案**
   - 如果系統無法直接開啟檔案，會顯示「開啟方式」選單，讓用戶選擇其他應用

### 使用體驗

當用戶在筆記中點擊圖片或影片的「用系統應用打開」按鈕時：

- **圖片**：會在系統的照片檢視器中開啟，支援縮放、分享等功能
- **影片**：會在系統的影片播放器中開啟，支援完整的播放控制
- **其他檔案**：維持原有的應用內預覽功能

### 技術細節

修改的檔案：
- `ios/Runner/AppDelegate.swift`

主要變更：
```swift
// 檢測檔案類型
let fileExtension = fileURL.pathExtension.lowercased()
let isImage = imageExtensions.contains(fileExtension)
let isVideo = videoExtensions.contains(fileExtension)

// 圖片和影片使用系統開啟
if isImage || isVideo {
    UIApplication.shared.open(fileURL, options: [:]) { success in
        result(success)
    }
}
```

### 測試建議

1. 在 iPhone 上建立包含圖片和影片的筆記
2. 點擊媒體檔案，進入全螢幕檢視器
3. 點擊右上角的「用系統應用打開」按鈕
4. 驗證圖片和影片是否在系統瀏覽器中開啟
5. 測試其他檔案類型（如 PDF）是否仍然使用應用內預覽

### 兼容性
- iOS 12.0 及以上版本
- 所有圖片和影片格式
- 不影響 Android 平台的現有功能

### 注意事項
- 檔案會先解密並儲存到臨時目錄，然後由系統應用開啟
- 系統應用開啟的檔案在退出應用時會自動清理
- 如果系統無法識別檔案類型，會顯示「開啟方式」選單
