# 媒體功能架構圖

## 系統架構

```
┌─────────────────────────────────────────────────────────────────┐
│                         用戶介面層 (UI Layer)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NoteEditorScreen                                               │
│  ┌────────────────┐   ┌──────────────┐   ┌─────────────┐      │
│  │  📎 附件按鈕    │──>│  選擇選單     │──>│  媒體選擇器  │      │
│  └────────────────┘   │  - 圖片       │   └─────────────┘      │
│                       │  - 影片       │                         │
│  ┌────────────────┐   │  - 檔案       │   ┌─────────────┐      │
│  │ MediaGallery   │   └──────────────┘   │ MediaViewer │      │
│  │  Widget        │<──────────────────────│  (全螢幕)   │      │
│  └────────────────┘                       └─────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      服務層 (Service Layer)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  MediaService                    CryptoService                  │
│  ┌─────────────────┐            ┌──────────────┐               │
│  │ pickImages()    │            │ encryptBytes │               │
│  │ pickVideo()     │───────────>│ decryptBytes │               │
│  │ pickFiles()     │            └──────────────┘               │
│  │ decryptMedia()  │                    ↓                       │
│  └─────────────────┘            ┌──────────────┐               │
│          ↓                      │  AES-256     │               │
│  ┌─────────────────┐            │  加密演算法   │               │
│  │ 生成縮圖        │            └──────────────┘               │
│  │ (影片)          │                                            │
│  └─────────────────┘                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      狀態管理層 (State Layer)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  NoteProvider                                                   │
│  ┌──────────────────────────────────────────┐                  │
│  │ addNote(content, mediaAttachments)       │                  │
│  │ updateNote(note, content, mediaAttachments)│                │
│  │ updateNoteDebounced(...)                 │                  │
│  └──────────────────────────────────────────┘                  │
│                       ↓                                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      資料層 (Data Layer)                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  HiveDatabaseService                                            │
│  ┌────────────────────────────────────┐                        │
│  │ Hive Box (加密儲存)                 │                        │
│  ├────────────────────────────────────┤                        │
│  │  Note (typeId: 0)                  │                        │
│  │  ├─ id                             │                        │
│  │  ├─ content (加密)                  │                        │
│  │  ├─ createdAt                      │                        │
│  │  ├─ updatedAt                      │                        │
│  │  └─ mediaAttachments []            │                        │
│  │      └─ MediaAttachment (typeId: 1)│                        │
│  │         ├─ id                      │                        │
│  │         ├─ fileName                │                        │
│  │         ├─ encryptedData (加密)     │                        │
│  │         ├─ mediaTypeIndex          │                        │
│  │         ├─ fileSize                │                        │
│  │         ├─ mimeType                │                        │
│  │         └─ thumbnailData (加密)     │                        │
│  └────────────────────────────────────┘                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 資料流程

### 1. 添加媒體流程

```
使用者操作
    ↓
點擊 📎 按鈕
    ↓
選擇媒體類型 (圖片/影片/檔案)
    ↓
MediaService.pickXXX()
    ↓
讀取檔案 bytes
    ↓
CryptoService.encryptBytes(bytes, password)
    ↓
創建 MediaAttachment 物件
    ↓
添加到 _mediaAttachments 列表
    ↓
setState() 更新 UI
    ↓
MediaGalleryWidget 顯示媒體
    ↓
點擊儲存按鈕
    ↓
NoteProvider.addNote() / updateNote()
    ↓
HiveDatabaseService 儲存
    ↓
加密資料寫入 Hive Box
```

### 2. 查看媒體流程

```
使用者點擊筆記
    ↓
NoteEditorScreen 載入
    ↓
讀取 note.mediaAttachments
    ↓
MediaGalleryWidget 渲染
    ↓
對每個媒體：
    ├─ 圖片: _MediaImageTile
    ├─ 影片: _MediaVideoTile
    └─ 檔案: _MediaFileTile
    ↓
載入時調用 MediaService.decryptMedia()
    ↓
CryptoService.decryptBytes(encryptedData, password)
    ↓
返回 Uint8List
    ↓
顯示在 UI (Image.memory / VideoPlayer / 檔案資訊)
```

### 3. 全螢幕查看流程

```
點擊媒體
    ↓
打開 MediaViewer
    ↓
使用 PhotoViewGallery
    ↓
對每個媒體頁面：
    ├─ 圖片: _ImageViewer
    │   └─ 解密 → Image.memory → 支援縮放
    ├─ 影片: _VideoViewer
    │   └─ 解密 → 臨時檔案 → VideoPlayer
    └─ 檔案: 顯示資訊
```

## 加密流程詳解

```
原始媒體檔案
    ↓
File.readAsBytes() → Uint8List
    ↓
CryptoService.encryptBytes()
    ├─ 1. 獲取/創建 salt (32 bytes)
    ├─ 2. 從 password + salt 派生金鑰 (PBKDF2)
    ├─ 3. 生成隨機 IV (16 bytes)
    ├─ 4. AES-256 加密 data
    └─ 5. 合併 IV + 加密資料
    ↓
Base64 編碼
    ↓
儲存為字串 (encryptedData)
```

## 解密流程詳解

```
從資料庫讀取 encryptedData (Base64 字串)
    ↓
Base64 解碼 → Uint8List
    ↓
CryptoService.decryptBytes()
    ├─ 1. 獲取 salt
    ├─ 2. 從 password + salt 派生相同金鑰
    ├─ 3. 分離 IV (前 16 bytes)
    ├─ 4. 分離加密資料 (剩餘 bytes)
    └─ 5. AES-256 解密
    ↓
原始檔案 Uint8List
    ↓
顯示在 UI
```

## UI 組件層次結構

```
NoteEditorScreen
├─ AppBar
│  ├─ 📎 附件按鈕 (onPressed: _showMediaOptions)
│  ├─ 📋 複製按鈕
│  ├─ 🗑️ 刪除按鈕
│  └─ 💾 儲存按鈕
│
├─ Body
│  └─ SingleChildScrollView
│     └─ Column
│        ├─ TextField (筆記內容)
│        └─ MediaGalleryWidget (如果有媒體)
│           ├─ _buildImageGrid() → GridView
│           │  └─ _MediaImageTile (每個圖片)
│           ├─ _buildVideosList() → Column
│           │  └─ _MediaVideoTile (每個影片)
│           └─ _buildFilesList() → Column
│              └─ _MediaFileTile (每個檔案)
│
└─ BottomSheet (選擇媒體時)
   ├─ 添加圖片 → MediaService.pickImages()
   ├─ 添加影片 → MediaService.pickVideo()
   └─ 添加檔案 → MediaService.pickFiles()
```

## 效能優化策略

```
1. 延遲載入 (Lazy Loading)
   └─ 媒體僅在需要顯示時才解密
   
2. 縮圖快取
   └─ 影片縮圖一次生成，加密儲存
   
3. RepaintBoundary
   └─ 包裝媒體組件，減少重繪範圍
   
4. AutomaticKeepAliveClientMixin
   └─ NoteCard 維持狀態，避免重建
   
5. SingleChildScrollView
   └─ 大量媒體時，支援滾動
   
6. 圖片壓縮
   └─ image_picker 自動壓縮到 2048x2048, 85% 質量
```

## 安全性層次

```
第 1 層：應用層加密
└─ 使用者密碼 + PBKDF2 (10000 iterations)

第 2 層：資料加密
└─ AES-256 加密所有媒體資料

第 3 層：獨立 IV
└─ 每個媒體使用唯一的初始化向量

第 4 層：Hive 加密
└─ Hive Box 使用派生金鑰加密

第 5 層：系統安全
└─ iOS Keychain / Android Keystore 儲存密碼雜湊
```

## 總結

這個架構實現了：
- ✅ 清晰的職責分離
- ✅ 完整的加密保護
- ✅ 良好的使用者體驗
- ✅ 高效能的媒體處理
- ✅ 可擴展的設計

所有組件協同工作，提供安全、流暢的媒體管理體驗！
