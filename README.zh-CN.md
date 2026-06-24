<div align="center">

# NeatWhisky 🥃
**从零到能玩，全程一键 —— 不用命令行，不用懂 Wine。**

在你的 Apple 芯片 Mac 上跑 Steam。NeatWhisky 帮你把一切装好，并修掉原生 Wine 上
让 Steam 无法正常使用的那些 bug。

[English](README.md) · 简体中文

</div>

---

## NeatWhisky 是什么？

NeatWhisky 是已归档项目 [Whisky](https://github.com/Whisky-App/Whisky) 的一个持续维护分支。
Whisky 停在了 Wine 7.7，其作者明确表示**不会再为 Steam 这类具体应用做修复**。
**NeatWhisky 正是从这里接手。**

它的目标很简单：让一个完全的小白，能从一台干净的 Mac，**一键直达「在 Steam 上玩游戏」**，
全程不碰命令行，也不需要知道「Wine」「bottle」「前缀」是什么。

## 它解决的问题

在原生的现代 Wine 环境下，Apple 芯片上的 Steam 有一连串问题：

| 现象 | NeatWhisky |
| --- | --- |
| 中文乱码 / 缺字（方块、问号） | 自动修复 |
| 闪退 / `steamwebhelper` 崩溃循环 | 已修复（现代 Wine） |
| 能启动但界面全黑 | 已修复（CEF 单进程包装器） |
| 关不掉、不停自动重启 | 已修复（Job Object 进程管理） |

## 使用方式（对你而言）

1. 下载 NeatWhisky，拖进「应用程序」。
2. 打开，点「开始」。
3. 看进度条。NeatWhisky 会自动：
   - 检测你的 Mac，必要时安装 Rosetta 2；
   - 装好现代 Wine + 全开源图形栈（DXVK + MoltenVK）；
   - 创建专用的 Steam 环境；
   - **下载并静默安装最新版 Steam**；
   - 套用上面所有修复。
4. Steam 正常打开、中文正常、不黑屏、能正常关闭。

> 重度 3A 大作不在「开箱即用」的承诺范围内：NeatWhisky 使用全开源图形栈，
> 不打包 Apple 的 Game Porting Toolkit，也不打包 CrossOver 组件。

## 当前状态

早期开发中。构建计划见 [`docs/`](docs/)，技术原理详解见
[`docs/how-it-works.html`](docs/how-it-works.html)。

## 运行要求

- Apple 芯片（M 系列）Mac
- macOS Sonoma 14.0 及以上

## 许可与署名

NeatWhisky 是 Whisky 的衍生作品，遵循 **GPL-3.0**（见 [`LICENSE`](LICENSE)）。
Fork 血缘与相对上游的改动清单见 [`NOTICE.md`](NOTICE.md)。
