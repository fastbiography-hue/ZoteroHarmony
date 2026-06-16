# Zotero for HarmonyOS

Zotero 鸿蒙版 — 开源文献管理工具。

基于 Zotero Desktop (AGPL-3.0) 移植到 OpenHarmony/HarmonyOS 平台，
使用 ArkTS + ArkUI 重写。

## 当前状态

🚧 开发中 (Alpha) — 当前目标是逐步复刻 Zotero Desktop 的核心功能、信息架构和跨平台工作台体验。

完整差距清单见 [docs/ZOTERO_DESKTOP_PARITY.md](docs/ZOTERO_DESKTOP_PARITY.md)。

### 模块状态

| 模块 | 状态 | 说明 |
|------|------|------|
| model/ | 🚧 Partial | 数据模型层已搭建，Item 反序列化仍需补全 |
| api/ | 🚧 Partial | HTTP 客户端 + Zotero Web API v3 端点骨架 |
| database/ | 🚧 Partial | SQLite 封装 + Schema 迁移基础 |
| sync/ | 🚧 Partial | 增量同步引擎 + Runner，仍需冲突/进度 UI |
| ui/ | 🚧 Partial | 三栏工作台、详情面板和表单组件持续对齐 Zotero Desktop |
| reader/ | 🚧 Partial | PDF 阅读器和批注系统基础，仍需完整 reader parity |
| citation/ | 🚧 Partial | CSL 样式加载存在 stub fallback，需接入完整 citeproc 能力 |
| import/ | 🚧 Partial | BibTeX/RIS/CSL JSON 导入导出基础，需补 wizard/预览/错误处理 |
| search/ | 🚧 Partial | 搜索引擎 + 高级搜索 UI，需持久化保存搜索和全文索引联动 |

### 技术栈

- **语言**: ArkTS (TypeScript 严格模式)
- **UI 框架**: ArkUI (@Component/@State/@Link)
- **数据库**: @ohos.data.relationalStore (SQLite)
- **网络**: @ohos.net.http
- **构建**: hvigor (DevEco Studio)

## 构建

1. 安装 DevEco Studio 6.1.0+
2. 打开本项目目录
3. 运行 `assembleHap`

## 开源协议

AGPL-3.0 — 与 Zotero Desktop 保持一致。

## 致谢

基于 [Zotero](https://github.com/zotero/zotero) 项目，
由 Corporation for Digital Scholarship 维护。
