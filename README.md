# CheatiOSVip DSW

> **Trình quản lý file cho iPhone/iPad — không cần jailbreak**  
> Hỗ trợ iOS 17 · 18 · 26 | Cài qua AltStore / Sideloadly / TrollStore

---

## © Bản quyền & Tác quyền

| Vai trò | Thông tin |
|---|---|
| **Người mod & phát triển bản này** | **HỒ XUÂN CẢNH** (Cảnh iOS Crack) |
| **Liên hệ** | hoxuancanh888@gmail.com |
| **Thương hiệu bản mod** | CheatiOSVip DSW |

Toàn bộ giao diện SwiftUI, thiết kế UX/UI dark-tech, các tính năng mở rộng và bản build phân phối trong project này được **tạo ra và sở hữu bởi HỒ XUÂN CẢNH**.

Nghiêm cấm:
- Sao chép giao diện, tên thương hiệu hoặc bản build
- Phân phối lại dưới tên khác mà không ghi rõ nguồn gốc
- Thương mại hoá bất kỳ phần nào mà không có văn bản cho phép của tác giả

---

## 🔓 Mã nguồn gốc & Tín dụng

Bản mod này được xây dựng **dựa hoàn toàn** trên hai mã nguồn mở sau. Toàn bộ công sức kỹ thuật lõi thuộc về các tác giả đó:

### FilzaSlop
| | |
|---|---|
| **Repository** | [0xjohnnydev/FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop) |
| **Chủ sở hữu gốc** | **0xjohnnydev** |
| **Chức năng cung cấp** | Cơ chế bypass sandbox qua bundle ID `com.apple.mobile.MobileHouseArrest` + MCM container activation (MCMFilzaStart, MCMLease) — cho phép đọc/duyệt container của mọi app mà không cần jailbreak |
| **Hỗ trợ iOS** | 17 · 18 · 26 · 27 beta |

### kexploit_opa334
| | |
|---|---|
| **Repository** | [opa334/kexploit_opa334](https://github.com/opa334) |
| **Chủ sở hữu gốc** | **opa334** |
| **Chức năng cung cấp** | Kernel exploit chain cho iOS 17–26 (kexploit, sandbox_escape, bad_query, krw) |

> **Tóm tắt:** CheatiOSVip DSW = Giao diện & UX bởi Cảnh iOS Crack + Lõi kỹ thuật bởi 0xjohnnydev + opa334.  
> Bản này **không** thay thế hay cạnh tranh với các dự án gốc.

---

## ⚠️ Cảnh báo quan trọng

### ⚠️ Cảnh báo pháp lý
- Phần mềm này sử dụng **kỹ thuật vượt sandbox của iOS** — vi phạm Điều khoản Sử dụng của Apple.
- Sử dụng phần mềm này có thể dẫn đến **vô hiệu hoá bảo hành**, khoá tài khoản Apple ID hoặc brick thiết bị.
- **Người dùng hoàn toàn tự chịu trách nhiệm** về mọi hậu quả phát sinh.
- Tác giả (HỒ XUÂN CẢNH) **không chịu bất kỳ trách nhiệm pháp lý nào** đối với thiệt hại phát sinh từ việc sử dụng phần mềm.

### ⚠️ Cảnh báo kỹ thuật
- Chỉ hỗ trợ thiết bị **arm64** (iPhone 6s trở lên với iOS 17+).
- **KHÔNG dùng** trên thiết bị đã jailbreak — xung đột kernel exploit có thể gây crash hoặc boot loop.
- Truy cập container app là **đọc/ghi trực tiếp** — xoá hoặc sửa file ứng dụng sai có thể khiến app đó không khởi động được.
- Không can thiệp vào file hệ thống của **ứng dụng ngân hàng, ví điện tử** hoặc dữ liệu nhạy cảm nếu không biết mình đang làm gì.

### ⚠️ Cảnh báo phân phối
- IPA build từ source này **chỉ dùng nội bộ / cá nhân**.
- Không được tải lên các store phân phối IPA công khai (AppValley, TutuBox, v.v.) mà không có sự đồng ý bằng văn bản của tác giả.

---

## 📲 Cài đặt

Yêu cầu: **iOS 17.0 – 26.x**, thiết bị arm64, chưa jailbreak.

```
1. Tải file .ipa từ Releases
2. Cài qua AltStore / Sideloadly / TrollStore / cert doanh nghiệp
3. Tin tưởng developer tại Cài đặt → Quản lý thiết bị
4. Mở app → cho phép nếu có thông báo
```

---

## 🔨 Build từ Source

```bash
git clone https://github.com/khoivua90-dot/CheatiOSShare.git
open CheatiOSShare/CheatiOSShare.xcodeproj
```

Trong Xcode:
1. Target `CheatiOSShare` → Signing & Capabilities → chọn Development Team
2. **Product → Archive**
3. Distribute App → Ad Hoc / Development → Export IPA

> **Lưu ý bắt buộc:** Bundle ID phải giữ nguyên `com.apple.mobile.MobileHouseArrest`. Thay đổi bundle ID sẽ làm mất toàn bộ khả năng truy cập container.

---

## 📁 Cấu trúc Source

```
CheatiOSShare.xcodeproj
CanhiOSShare/
├── CanhiOSShareApp.swift       ← Entry point
├── ContentView.swift           ← Root view
├── Info.plist                  ← Bundle ID: com.apple.mobile.MobileHouseArrest
├── CanhiOSShare-Bridging-Header.h
├── views/
│   ├── DesignSystem.swift      ← Dark-tech UI tokens, TechBackground, components
│   ├── HomeView.swift          ← Màn chính: device card + location tiles
│   ├── FileBrowserView.swift   ← Duyệt file, preview text
│   ├── AppListView.swift       ← Danh sách app đã cài
│   ├── VPNBlockView.swift      ← Chặn VPN/Proxy
│   ├── LoadingView.swift       ← Màn khởi động
│   └── SettingsView.swift      ← Cài đặt + thông tin bản quyền
├── helpers/
│   ├── AppState.swift          ← Startup: gọi MCMFilzaStart
│   ├── ContainerStore.swift    ← listFiles, readTextFile, appContainerPath
│   ├── InstalledAppService.swift ← Tải danh sách app qua MCM
│   └── NetworkSecurityMonitor.swift ← Phát hiện VPN/Proxy
├── exploit/                    ← MCM bypass (FilzaSlop - 0xjohnnydev)
│   ├── MCMBridge.h/m           ← MCMLease, container activation
│   ├── MCMFilzaIntegration.h/m ← MCMFilzaStart, MCMFilzaDataContainerPath
│   └── bad_query.h/c           ← Filesystem traversal grant
└── kexploit/                   ← Kernel exploit (opa334) — dùng cho iOS 26+
    ├── kexploit_opa334.h/m
    ├── sandbox_escape.h/m
    ├── krw.h/m
    └── ...
```

---

## 📜 Tuyên bố miễn trách đầy đủ

Phần mềm này được cung cấp "nguyên trạng" (as-is) không có bất kỳ bảo đảm nào, dù rõ ràng hay ngụ ý. Tác giả không bảo đảm phần mềm hoạt động không gián đoạn, không có lỗi, hoặc phù hợp cho mục đích cụ thể nào. Việc sử dụng phần mềm này hoàn toàn do người dùng tự quyết định và chịu rủi ro. Trong mọi trường hợp, tác giả không chịu trách nhiệm về bất kỳ thiệt hại trực tiếp, gián tiếp, ngẫu nhiên, đặc biệt hoặc hậu quả nào phát sinh từ việc sử dụng hoặc không thể sử dụng phần mềm này.
