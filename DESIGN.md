# Pawchive Downloader (iOS 巨魔专属版) - 项目设计与方案文档 (DESIGN.md)

> **文档说明**：本文档作为本项目开发的**单一可信源（Single Source of Truth）**。  
> 每次讨论达成的新共识、方案调整或功能取舍，都将即时同步更新至本文档，确保跨会话、跨周期开发过程中心智模型始终一致。

---

## 1. 项目基本信息与功能定位

- **目标平台**：iOS (专为 **巨魔 / TrollStore** 环境定制优化)
- **核心定位**：专注于 `pawchive.pw` 帖子内**【高清图片与视频】**的批量提取与高速下载（自动过滤非媒体杂项附件）。
- **界面外观**：**全 OLED 极致暗黑风格**（纯黑 `#000000` 背景、`#1C1C1E` 悬浮卡片、`#2C2C2E` 交互控件、`#0A84FF` 高亮天蓝）。
- **核心交互流程**：
  1. **手动输入/粘贴链接**：首页输入框提供清晰的【粘贴】按钮（**不主动刺探/检测剪贴板**，无感且干净）。
  2. **帖子画廊预览与挑选**：
     - 解析后展示 3 列自适应媒体网格与作者帖子头图信息卡片。
     - **默认都不选**（`isSelected: false`），由用户按需勾选或点击【全选】。
     - 点击缩略图可进入全屏原图查看器（支持双指捏合缩放、左右滑动切换）；视频带直观角标，点击直接切换选择状态。
     - 44x44 Apple HIG 标准大触控热区复选框，防止手滑误触。
  3. **双重导出目标**：
     - **直存相册**：将勾选的图片与视频直接存入 iOS 原生相册（支持按作者或标题归档建立专属相簿）。
     - **打包为 ZIP**：将勾选的图片与视频在本地打包为一个独立 `.zip` 压缩包，默认存入 App `Documents`，并在 iOS 原生“文件”App 中直接可见并支持一键分享。
  4. **非阻塞多任务下载队列架构（Non-blocking Task Queue）**：
     - **拒绝强模态锁定**：发起导出后弹出的下载面板支持随时收起（轻触背景、下滑手势或点击“收起后台”按钮），绝不阻塞或限制用户停留在当前页面。
     - **多任务连续添加**：用户可随意返回首页解析其他帖子并继续添加下载任务，底层自动按队列 FIFO 顺畅排队执行，防止多任务并发冲垮网络或触发服务器 429 限流。
     - **全局悬浮进度胶囊（Floating Download Pill）**：面板收起后，首页与画廊页底部常驻显示悬浮胶囊，实时展示“正在下载 (3/10) · 2.4 MB/s”或“X 个任务进行中”及进度条，轻触随时弹回下载管理面板。
     - **巨魔特权后台保活**：任务在后台或锁屏状态下持续下载不中断，完成后发送系统横幅与轻触震动反馈。

---

## 2. 巨魔系统 (TrollStore) 特权设计与技术方案

> 巨魔环境拥有不受 App Store 约束的私有 Entitlements 特权，全面解除 iOS 系统的后台与沙盒限制。

### 2.1 私有 Entitlements 配置 (`TrollStore.entitlements`)
在打包构建阶段注入核心后台保活与相册访问特权：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 1. 容器沙盒标识（保留标准沙盒以确保与 iOS“文件”App 100% 互通，必须显式指明 Bundle ID） -->
    <key>com.apple.private.security.container-required</key>
    <string>com.pawchive.pawchiveDownload</string>

    <!-- 2. 无限后台运行：彻底免除 iOS Watchdog 30s-3min 杀后台机制，锁屏全速下载 -->
    <key>com.apple.multitasking.unlimited</key>
    <true/>

    <!-- 3. TCC 隐私特权：免弹窗无感写入相册 -->
    <key>com.apple.private.tcc.allow</key>
    <array>
        <string>kTCCServicePhotos</string>
        <string>kTCCServiceMediaLibrary</string>
    </array>

    <!-- 4. 调试与基础特权 -->
    <key>get-task-allow</key>
    <true/>
</dict>
</plist>
```

> **为何移除 `com.apple.private.security.no-sandbox`？**  
> 经实测与底层系统分析，脱离沙盒会导致 iOS 系统的 `fileproviderd` 无法正确识别 App 容器，破坏 `UIFileSharingEnabled`（导致在系统“文件”App 的【我的 iPhone】中无法显示应用文件夹）。保留标准容器沙盒能确保 ZIP 归档在系统“文件”App 中直接呈现，且卸载时不残留垃圾文件。

---

## 3. 核心 API 与媒体提取规则

### 3.1 帖子链接与解析规则
- **支持链接格式**：`https://pawchive.pw/{service}/user/{user_id}/post/{post_id}`
  - 例：`https://pawchive.pw/patreon/user/30500811/post/170445231`
- **解析字段**：`service` (patreon/fanbox/fantia), `user_id`, `post_id`。

### 3.2 接口与下载地址构造
- **接口端点**：
  ```http
  GET https://pawchive.pw/api/v1/{service}/user/{user_id}/post/{post_id}
  ```
- **媒体白名单过滤**：
  - 图片类：`.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
  - 视频类：`.mp4`, `.mov`, `.m4v`, `.webm`
- **下载与预览地址**：
  - **高清原图/视频**：`https://file.pawchive.pw/data{path}?f={filename}`
  - **缩略图预览**：`https://img.pawchive.pw/thumbnail/data{path}`

---

## 4. 双导出模式与任务队列技术实现

### 4.1 模式 A：直接写入 iOS 相册 (Direct to Photos)
- **相册写入**：基于 `gal` 插件实现零弹窗直接写入原生相册。
- **专属相簿归档**：默认在相册中创建 `[Pawchive] {作者名} - {帖子标题}` 专属相簿。
- **存储优化**：保存到系统相册后，自动清除沙盒内的临时原图文件，防止占用双倍空间。

### 4.2 模式 B：本地打包为 ZIP (Pack to ZIP)
- **存储路径**：存放在 App 原生 **`Documents`** 目录（`getApplicationDocumentsDirectory()`）。
- **系统“文件”App 互通**：在 `Info.plist` 中启用 `UIFileSharingEnabled: true` 与 `LSSupportsOpeningDocumentsInPlace: true`。
- **流式打包**：下载媒体到临时缓存后，通过 `archive` 库打包为 `[Pawchive]_{作者名}_{帖子ID}.zip` 并存入 Documents，支持在下载面板中一键调用系统分享（AirDrop 等）。

### 4.3 多任务队列管理器 (DownloadTaskNotifier)
- **队列模型**：每个导出请求生成独立 `DownloadTask`，状态流转为：`queued` -> `downloading` -> `savingToAlbum` / `packingZip` -> `completed` / `failed` / `cancelled`。
- **线程控制**：任务内部依据用户设置并发数（1~8 线程）执行文件拉取；任务之间依序排队，避免并发过多触发服务端 429 速率限制。
- **细粒度控制**：支持单任务取消、全部取消、清除已完成任务，独立管理每个任务的进度与异常信息。

---

## 5. UI/UX 界面流程与暗黑规范

### 5.1 页面流转架构
```
[首页] (输入/粘贴链接 + 历史记录卡片 + 悬浮下载胶囊 + 设置)
  │
  ▼ 点击“解析”
[帖子画廊与挑选页] (作者卡片 + 全选/反选 + 3列媒体网格 + 悬浮胶囊 + 双导出按钮)
  ├─ 点击缩略图 -> 打开 [全屏原图查看器]
  ├─ 勾选项目 -> 实时统计“已选 X 项” (默认都不选)
  └─ 点击【存入系统相册】或【打包为 ZIP】
        │
        ▼ 弹出 (非模态，可随时收起或点击背景退出)
[下载任务管理面板 (DownloadSheet)] (多任务列表 + 速度/进度条 + 巨魔保活横幅 + ZIP一键分享)
        │
        ▼ 收起面板后
[全局悬浮下载胶囊 (FloatingDownloadPill)] (常驻于首页/画廊底部，实时同步进度，点击弹回面板)
```

### 5.2 统一 OLED 暗黑调色板 (`AppColors`)
- **主背景 (Background)**：`0xFF000000` (纯黑 OLED)
- **顶栏底栏 (BarBackground)**：`0xFF121214`
- **悬浮卡片 (CardBackground)**：`0xFF1C1C1E`
- **次级卡片/输入框 (SecondaryCard)**：`0xFF2C2C2E`
- **高亮品牌蓝 (Primary)**：`0xFF0A84FF`
- **文字主色 (TextPrimary)**：`0xFFFFFFFF`
- **文字副色 (TextSecondary)**：`0xFF8E8E93`
- **成功绿 (Success)**：`0xFF30D158`
- **危险红 (Destructive)**：`0xFFFF453A`

---

## 6. 技术选型清单

| 模块 | 选型 | 理由 |
| :--- | :--- | :--- |
| **网络层 / 下载** | `dio` | 支持原生下载进度回调、连接池管理、分段 Range 请求与重试 |
| **状态管理** | `flutter_riverpod` | 保证多任务队列、选择状态全局响应式与解耦 |
| **图片预览 / 缓存** | `cached_network_image` | 缩略图平滑加载、磁盘缓存，避免重复拉取 |
| **iOS 相册保存** | `gal` | 现代轻量相册写入库，与巨魔 TCC 特权完美契合 |
| **ZIP 归档压缩** | `archive` | 原生 Dart 流式压缩与打包，防 OOM |
| **原生分享** | `share_plus` | 支持调用 iOS 原生 AirDrop / 系统分享面板 |
| **本地持久化** | `shared_preferences` | 持久化保存用户偏好设置与最近解析历史列表 |
| **本地通知** | `flutter_local_notifications` | 巨魔后台任务完成向系统推送横幅与通知提醒 |

---

## 7. 方案变更记录 (Decision Changelog)

| 时间 | 变更内容 | 原因 / 讨论结论 |
| :--- | :--- | :--- |
| 2026-09-27 | 初始化基准架构与 API 规则 | 完成 pawchive.pw 逆向分析与真实接口数据验证 |
| 2026-09-27 | 目标环境确立为 **巨魔 (TrollStore)** | 解除标准 iOS 限制，引入私有特权：无上限后台任务、TCC 相册免弹窗、自由读写沙盒 |
| 2026-09-27 | 范围收敛为【图片与视频】 | 自动过滤内部杂项附件，打造纯粹画廊体验 |
| 2026-09-27 | 确立双重导出：相册 vs ZIP | 相册支持归类；ZIP 保存在 Documents 并挂载至 iOS“文件”App |
| 2026-09-27 | 明确**移除 `no-sandbox`** 特权 | 经推演，保留标准沙盒是 iOS“文件”App 能正确识别 Documents 容器的前提，避免过度设计 |
| 2026-09-27 | 确认视频交互规范与轻量化策略 | 视频仅作为可勾选项参与挑选、相册归档与 ZIP 打包，不内置播放器，保持极简轻量 |
| 2026-09-27 | 修正 `container-required` 权利字段 | 必须显式展开为实际 Bundle ID（`com.pawchive.pawchiveDownload`），防止 TrollStore 解析失败 |
| 2026-09-27 | 图片默认由全选改为**默认都不选** | 优化挑选体验，用户按需勾选或一键全选，避免大帖子误导出几十张不需要的内容 |
| 2026-09-27 | 修复画廊选择状态与导出按钮阻塞 | 将 post 数据正确写入 Riverpod 并注入 `GalleryScreen`；扩大勾选按钮热区为 44x44 |
| 2026-09-27 | 全站统一 **OLED 纯黑暗黑主题** | 修复卡片底色泛白问题，建立统一的 `AppColors` 暗黑配色方案 |
| 2026-09-27 | **重构非阻塞多任务下载队列架构** | 解决下载面板锁死界面的问题：面板可随时收起或后台化；引入多任务排队机制；增加全局常驻悬浮下载胶囊 (`FloatingDownloadPill`)，支持多帖子边看边下 |

---

## 8. 开发阶段里程碑 (Roadmap & Milestones)

- [x] **Phase 1**: 确定交互模型、原型流转与功能范围（已完全确认）
- [x] **Phase 2**: 实现数据模型层与解析服务 (`url_parser.dart`, `pawchive_api.dart`, `models/`)
- [x] **Phase 3**: 实现多任务下载与 ZIP 压缩核心引擎 (`download_service.dart`, `zip_service.dart`, `storage_service.dart`)
- [x] **Phase 4**: 构建完整 OLED 暗黑 UI 页面 (首页、画廊挑选页、全屏大图查看器、设置页、任务管理面板)
- [x] **Phase 5**: 串联状态管理 (Riverpod) 与巨魔后台保活配置
- [x] **Phase 6**: 非阻塞下载队列、全局悬浮胶囊与 GitHub Actions CI/CD 自动化打包构建验证
