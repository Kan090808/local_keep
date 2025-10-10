# 媒體功能權限設定指南

## iOS 設定

需要在 `ios/Runner/Info.plist` 中添加以下權限：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>需要訪問您的相簿來選擇要附加到筆記的圖片和影片</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>需要保存媒體到您的相簿</string>

<key>NSCameraUsageDescription</key>
<string>需要訪問相機來拍攝照片和影片</string>

<key>NSMicrophoneUsageDescription</key>
<string>需要訪問麥克風來錄製影片音頻</string>
```

### Info.plist 完整範例

在 `<dict>` 標籤內添加：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 現有的配置 -->
    
    <!-- 添加以下媒體權限 -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>需要訪問您的相簿來選擇要附加到筆記的圖片和影片</string>
    
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>需要保存媒體到您的相簿</string>
    
    <key>NSCameraUsageDescription</key>
    <string>需要訪問相機來拍攝照片和影片</string>
    
    <key>NSMicrophoneUsageDescription</key>
    <string>需要訪問麥克風來錄製影片音頻</string>
</dict>
</plist>
```

## Android 設定

需要在 `android/app/src/main/AndroidManifest.xml` 中添加權限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 添加以下權限 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.CAMERA"/>
    
    <!-- Android 13+ 的新權限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    
    <application
        ...>
        <!-- 現有的配置 -->
    </application>
</manifest>
```

### Android 完整 AndroidManifest.xml 範例

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 網路權限（如果需要） -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <!-- 媒體訪問權限 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.CAMERA"/>
    
    <!-- Android 13+ (API 33+) 的細分權限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    
    <application
        android:label="Local Keep"
        android:name="${applicationName}"
        android:icon="@mipmap/launcher_icon">
        
        <!-- 添加 FileProvider -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
        
        <!-- 現有的 activity 配置 -->
        <activity
            android:name=".MainActivity"
            ...>
        </activity>
    </application>
</manifest>
```

### 創建 file_paths.xml

在 `android/app/src/main/res/xml/` 目錄下創建 `file_paths.xml`：

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="."/>
    <cache-path name="cache" path="."/>
    <files-path name="files" path="."/>
</paths>
```

## 測試權限

### iOS 測試
1. 首次運行應用時，會彈出權限請求對話框
2. 如果拒絕了權限，可以在 設定 -> Local Keep 中重新開啟

### Android 測試
1. Android 6.0+ 會在首次使用功能時請求權限
2. 如果拒絕了權限，可以在 設定 -> 應用程式 -> Local Keep -> 權限 中開啟

## 權限請求時機

應用會在以下情況請求權限：
- 首次點擊「添加圖片」時 → 相簿訪問權限
- 首次點擊「添加影片」時 → 相簿訪問權限
- 如果添加相機功能時 → 相機權限

## 常見問題

### Q: 用戶拒絕權限後怎麼辦？
A: 應用會顯示錯誤訊息，提示用戶到設定中開啟權限。可以考慮添加一個設定頁面的快捷方式。

### Q: Android 13+ 需要特別注意什麼？
A: Android 13 引入了細分的媒體權限（READ_MEDIA_IMAGES, READ_MEDIA_VIDEO），不再使用 READ_EXTERNAL_STORAGE。我們已經在 AndroidManifest.xml 中添加了這些權限。

### Q: iOS 模擬器無法訪問相簿？
A: 模擬器可能沒有相簿內容。建議：
1. 使用 Safari 下載一些圖片到模擬器
2. 或使用真實設備測試

## 開發建議

1. **測試所有權限場景**：
   - 允許權限
   - 拒絕權限
   - 拒絕後再允許
   
2. **提供清晰的權限說明**：
   - 在請求權限前顯示說明
   - 解釋為什麼需要這些權限
   
3. **優雅的降級處理**：
   - 沒有權限時提供替代方案
   - 顯示友善的錯誤訊息

## 參考資料

- [Flutter image_picker 文檔](https://pub.dev/packages/image_picker)
- [Flutter file_picker 文檔](https://pub.dev/packages/file_picker)
- [Android 權限文檔](https://developer.android.com/guide/topics/permissions/overview)
- [iOS 權限文檔](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
