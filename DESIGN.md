# Pawchive Downloader (iOS 巨魔专属版) - 项目设计与方案文档 (DESIGN.md)

> **文档说明**：本文档作为本项目开发的**单一可信源（Single Source of Truth）**。  
> 每次讨论达成的新共识、方案调整或功能取舍，都将即时同步更新至本文档，确保跨会话、跨周期开发过程中心智模型始终一致。

---

## 1. 项目基本信息与功能定位

- **目标平台**：iOS (专为 **巨魔 / TrollStore** 环境定制优化)
- **核心定位**：专注于 `pawchive.pw` 帖子内**【高清图片与视频】**的批量提取与高速下载（自动过滤非媒体杂项附件）。
- **核心交互流程**：
  1. **手动输入/粘贴链接**：首页输入框提供清晰的【粘贴】按钮（**不主动刺探/检测剪贴板**，无感且干净）。
  2. **帖子画廊预览与挑选**：解析后展示 3 列自适应媒体网格，支持单张原图全屏预览（手势捏合缩放）、批量全选/反选与实时计数。
  3. **双重导出目标**：
     - **直存相册**：将勾选的图片与视频直接存入 iOS 原生相册（支持按作者或标题归档建立专属相簿）。
     - **打包为 ZIP**：将勾选的图片与视频在本地打包为一个独立 `.zip` 压缩包，默认存入 App `Documents`，并在 iOS 原生“文件”App 中直接可见。
  4. **巨魔无感特权**：真后台下载不中断，保存相册无需弹窗确认。

---

## 2. 巨魔系统 (TrollStore) 特权设计与技术方案

> 巨魔环境拥有不受 App Store 约束的私有 Entitlements 特权，全面解除 iOS 系统的后台与沙盒限制。

### 2.1 私有 Entitlements 配置 (`TrollStore.entitlements`)
在打包构建阶段注入核心后台保活权限（**保留标准沙盒以确保与 iOS“文件”App 完美互通**）：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 1. 无限后台运行：彻底免除 iOS Watchdog 30s-3min 杀后台机制，锁屏全速下载 -->
    <key>com.apple.multitasking.unlimited</key>
    <true/>
    
    <!-- 2. 调试与基础特权 -->
    <key>get-task-allow</key>
    <true/>
</dict>
</plist>
```
> **为何不使用 `com.apple.private.security.no-sandbox`？**  
> 经架构评估，脱离沙盒会导致 iOS 系统的 `fileproviderd` 无法正确识别 App 容器，从而破坏 `UIFileSharingEnabled`（导致在系统“文件”App 的【我的 iPhone】中无法显示文件夹）。保留标准容器沙盒能确保 ZIP 归档与系统“文件”App 100% 互通，且卸载时不残留垃圾文件。

### 2.2 真·后台下载保活策略 (True Background Engine)
1. **进程不断流**：利用 `com.apple.multitasking.unlimited` 申请长期任务，不被系统挂起，锁屏与切后台正常全速下载。
2. **下载队列与状态恢复**：切换到后台时，Dio 队列正常轮询推进，支持断点续传。
3. **后台通知反馈**：本地通知（Local Notifications）在后台任务完成时向系统推送横幅：“{帖子名} 共 X 张原图已全部下载完成”。
4. **智能释放**：下载完成后自动释放保活，避免不必要的电池消耗。

---

## 3. 核心 API 与媒体提取规则

### 3.1 帖子链接与解析规则
- **支持链接格式**：`https://pawchive.pw/{service}/user/{user_id}/post/{post_id}`
  - 例：`https://pawchive.pw/patreon/user/30500811/post/170445231`
- **解析字段**：`service` (patreon/fanbox), `user_id`, `post_id`。

### 3.2 接口与下载地址构造（实测验证可用）
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

### 3.3 分段下载与断点续传引擎 (Segmented / Chunked Engine)
- **CDN 验证结论**：`file.pawchive.pw` 与 `img.pawchive.pw` 均原生返回 `Accept-Ranges: bytes` 与 `206 Partial Content`。
- **大文件分片**：大视频/大附件按 20MB~50MB 切割分块，分配 3~4 个并发 Worker，使用 Dart `RandomAccessFile.setPosition(start)` 直接写入对应磁盘偏移。
- **普通原图**：任务级并发（默认 4 线程），支持单图网络异常断点续传。

---

## 4. 双导出模式技术实现

### 4.1 模式 A：直接写入 iOS 相册 (Direct to Photos)
- **图片保存**：利用 `gal.putImage(filePath, album: albumName)`。
- **视频保存**：利用 `gal.putVideo(filePath, album: albumName)`。
- **相册命名规范**：默认在相册中创建 `[Pawchive] {作者名} - {帖子标题}` 专属相簿。
- **时间线对齐**：可选将帖子原发布时间作为 Exif 日期写入相册。

### 4.2 模式 B：本地打包为 ZIP (Pack to ZIP)
- **存储路径**：存放在 App 原生 **`Documents`** 目录（`getApplicationDocumentsDirectory()`）。
- **iOS“文件”App 互通配置**：
  在 `ios/Runner/Info.plist` 中启用 `UIFileSharingEnabled: true` 与 `LSSupportsOpeningDocumentsInPlace: true`。
  用户打开 iPhone 自带的**“文件”App -> 我的 iPhone -> Pawchive Download**，即可直接查看并管理所有 `.zip` 文件。
- **流式打包**：下载媒体到临时缓存后，通过 `archive` 库流式压缩为 `[Pawchive]_{作者名}_{帖子ID}.zip` 存入 Documents。

---

## 5. UI/UX 界面流程与规范

### 5.1 页面流转架构
```
[首页] (手动输入/粘贴链接 + 历史记录卡片 + 右上角设置)
  │
  ▼ 点击“解析”
[帖子画廊与挑选页] (作者卡片 + 全选/反选工具条 + 3列媒体网格 + 悬浮双导出按钮)
  ├─ 点击缩略图 -> 打开 [全屏原图/视频查看器] (双指缩放/左右滑)
  ├─ 勾选项目 -> 实时统计“已选 X 项”
  └─ 点击【存入系统相册】或【打包为 ZIP】
        │
        ▼ 弹出
[下载进度半屏底板 (Progress Sheet)] (进度条 + 速度 + 巨魔后台保活 + 震动与通知)
```

### 5.2 各页面核心规范
1. **首页 (Home Screen)**：
   - iOS 大标题导航栏（`Pawchive`），右上角设置图标。
   - 输入框 + 右侧显式【粘贴】按钮（**不主动检测/侵犯剪贴板**）。
   - 历史记录卡片列表（封面、作者、标题、数量），支持快速再次查看与导出。
2. **帖子画廊预览页 (Post Gallery Screen)**：
   - 顶部卡片：作者头像、昵称、Patreon/Fanbox 平台标签、帖子标题、发布时间。
   - 工具条：左侧“已选 X / 共 Y 项”，右侧【全选 / 取消全选】。
   - 3 列自适应媒体网格：右上角带 iOS 蓝色圆圈对勾，视频带播放图标；点击本体进全屏大图查看器。
   - 底部悬浮胶囊：【📦 打包为 ZIP】与【📥 存入系统相册】。
3. **设置页 (Settings Screen)**：
   - **下载与性能**：并发数滑块 (1~8，默认 4)、大文件分段加速开关、自动重试次数。
   - **相册与导出偏好**：专属相册开关、Exif 原发布时间对齐开关。
   - **ZIP 文件归档**：快捷打开/查看 Documents 目录。
   - **巨魔特权与后台**：无限后台保活开关、完成通知与震动、任务完成自动释放保活。
   - **存储与缓存**：缩略图缓存大小统计与一键清空。

---

## 6. 技术选型清单

| 模块 | 选型 | 理由 |
| :--- | :--- | :--- |
| **网络层 / 下载** | `dio` | 支持原生下载进度回调、连接池管理、分段 Range 请求与重试 |
| **状态管理** | `flutter_riverpod` | 保证响应式状态、UI 与逻辑解耦、易测试 |
| **图片预览 / 缓存** | `cached_network_image` | 缩略图平滑加载、磁盘缓存，避免重复拉取 |
| **iOS 相册保存** | `gal` | 现代轻量相册写入库，对 iOS 权限与相册处理简洁 |
| **ZIP 归档压缩** | `archive` | 原生 Dart 流式压缩与打包 |
| **权限声明** | `permission_handler` | 统一请求 iOS 相册及网络权限 |
| **原生分享** | `share_plus` | 支持调用 iOS 原生 AirDrop / 系统分享面板 |
| **本地持久化** | `shared_preferences` | 持久化保存用户偏好设置与最近解析历史列表 |
| **本地通知** | `flutter_local_notifications` | 巨魔后台任务完成向系统推送横幅与通知提醒 |

---

## 7. 方案变更记录 (Decision Changelog)

| 时间 | 变更内容 | 原因 / 讨论结论 |
| :--- | :--- | :--- |
| 2026-09-27 | 初始化基准架构与 API 规则 | 完成 pawchive.pw 逆向分析与真实接口数据验证 |
| 2026-09-27 | 目标环境确立为 **巨魔 (TrollStore)** | 解除标准 iOS 限制，引入私有特权：无上限后台任务、TCC 相册免弹窗、自由读写沙盒 |
| 2026-09-27 | 实测验证分段下载 (HTTP Range 206) | 验证通过，确立大文件分块直写 + 小图并发续传引擎 |
| 2026-09-27 | 范围收敛为【图片与视频】 | 自动过滤内部杂项附件，打造纯粹画廊体验 |
| 2026-09-27 | 确立双重导出：相册 vs ZIP | 相册支持归类；ZIP 保存在 Documents 并挂载至 iOS“文件”App |
| 2026-09-27 | 敲定完整 UI 规范与设置页细节 | 不自动检测剪贴板；包含首页历史、画廊多选、全屏查看器、5大设置分组 |
| 2026-09-27 | 明确**移除 `no-sandbox`** 特权 | 经推演，保留标准沙盒是 iOS“文件”App 能正确识别 Documents 容器的前提，避免过度设计 |
| 2026-09-27 | 确认视频交互规范与轻量化策略 | 视频仅作为可勾选项参与挑选、相册归档与 ZIP 打包，不内置播放器，保持极简轻量；采用 STORE 模式流式打包防 OOM；相册保存成功后自动清除沙盒临时文件；网络完全依赖系统全局分流 |

---

## 8. 开发阶段里程碑 (Roadmap & Milestones)

- [x] **Phase 1**: 确定交互模型、原型流转与功能范围（已完全确认）
- [ ] **Phase 2**: 实现数据模型层与解析服务 (`url_parser.dart`, `pawchive_api.dart`, `models/`)
- [ ] **Phase 3**: 实现下载与 ZIP 压缩核心引擎 (`download_service.dart`, `zip_service.dart`, `storage_service.dart`)
- [ ] **Phase 4**: 构建完整 UI 页面 (首页、画廊挑选页、全屏大图查看器、设置页、下载进度半屏底板)
- [ ] **Phase 5**: 串联状态管理 (Riverpod) 与巨魔后台保活配置
- [ ] **Phase 6**: 全量构建验证与异常容错测试
