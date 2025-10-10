# 自動鎖定機制說明

## 概述

本應用實現了智能的自動鎖定機制，在保護隱私的同時不會干擾正常的檔案選擇操作。

## 工作原理

### 🔒 鎖定條件

應用只會在以下**所有**條件都滿足時自動鎖定：

1. ✅ 用戶已設定密碼
2. ✅ 應用進入後台（`AppLifecycleState.paused`）
3. ✅ 當前**沒有**正在進行的檔案選擇操作

### 🎯 Flag 機制

使用 `AppLifecycleService` 來管理檔案選擇狀態：

```dart
class AppLifecycleService {
  bool _isPickingFile = false;
  
  void startFilePicking() {
    _isPickingFile = true;  // 開始選擇檔案，防止鎖定
  }
  
  void endFilePicking() {
    _isPickingFile = false;  // 完成選擇，允許鎖定
  }
}
```

### 📂 檔案選擇流程

所有檔案選擇方法都使用 `try-finally` 模式確保 flag 正確更新：

```dart
static Future<List<MediaAttachment>?> pickImages(String password) async {
  final lifecycleService = AppLifecycleService();
  try {
    lifecycleService.startFilePicking();  // 1. 設置 flag
    
    // 2. 打開檔案選擇器（此時離開 app 不會鎖定）
    final images = await picker.pickMultiImage(...);
    
    // 3. 處理選擇的檔案
    return attachments;
  } catch (e) {
    // 處理錯誤
    return null;
  } finally {
    lifecycleService.endFilePicking();  // 4. 無論如何都重置 flag
  }
}
```

### 🛡️ 安全保障

#### Finally 區塊保證
- ✅ **正常完成**：選擇檔案後 flag 重置
- ✅ **取消操作**：用戶取消後 flag 重置
- ✅ **發生錯誤**：出錯後 flag 重置
- ✅ **用戶中斷**：任何情況下 flag 都會重置

## 實現位置

### 核心服務
- **`lib/services/app_lifecycle_service.dart`**
  - 管理檔案選擇狀態 flag
  - 單例模式，全局可訪問

### 生命週期監聽
- **`lib/main.dart`**
  - 監聽應用生命週期變化
  - 檢查鎖定條件
  - 根據 flag 決定是否鎖定

### 檔案選擇服務
- **`lib/services/media_service.dart`**
  - `pickImages()` - 選擇圖片
  - `pickVideo()` - 選擇影片
  - `pickFiles()` - 選擇任意檔案
  - 所有方法都設置 flag

## 使用場景

### ✅ 不會鎖定的情況

| 情境 | 原因 |
|------|------|
| 選擇圖片時離開 | `isPickingFile = true` |
| 選擇影片時離開 | `isPickingFile = true` |
| 選擇檔案時離開 | `isPickingFile = true` |
| 未設定密碼時離開 | `hasPassword = false` |
| 用戶取消選擇後 | flag 已在 finally 中重置 |

### 🔒 會鎖定的情況

| 情境 | 原因 |
|------|------|
| 切換到其他 app | 已設密碼 + 不在選擇檔案 |
| 按 Home 鍵離開 | 已設密碼 + 不在選擇檔案 |
| 接聽電話 | 已設密碼 + 不在選擇檔案 |
| 檢視通知 | 已設密碼 + 不在選擇檔案 |

## 測試檢查清單

- [ ] 選擇圖片時不鎖定
- [ ] 選擇影片時不鎖定
- [ ] 選擇檔案時不鎖定
- [ ] 取消選擇後能正常鎖定
- [ ] 選擇完成後能正常鎖定
- [ ] 未設密碼時永不鎖定
- [ ] 已設密碼時正常鎖定
- [ ] 選擇錯誤時 flag 正確重置

## 調試日誌

應用會輸出以下日誌方便調試：

```
AppLifecycleService: isPickingFile = true
App lifecycle state changed to: paused
Skipping lock: File picking in progress
AppLifecycleService: isPickingFile = false
```

## 優勢

1. **精確控制**：只在真正需要時防止鎖定
2. **安全可靠**：finally 確保 flag 一定會重置
3. **用戶友好**：選擇檔案流暢，無中斷
4. **保護隱私**：其他情況仍然自動鎖定
5. **易於擴展**：新的檔案選擇方法只需遵循相同模式

## 未來擴展

如需添加新的檔案選擇功能，請遵循以下模式：

```dart
static Future<Result?> yourNewPickMethod() async {
  final lifecycleService = AppLifecycleService();
  try {
    lifecycleService.startFilePicking();
    
    // 你的檔案選擇邏輯
    
  } finally {
    lifecycleService.endFilePicking();
  }
}
```

---

**最後更新**：2025-10-11
**版本**：v2.0 - Flag-based mechanism
