# Godot MCP

当前项目使用 Godot-MCP 0.31.0、本地 GameDev-MCP-Server 9.2.13 和 .NET SDK 8.0.426。

## 启动

在项目根目录运行：

```powershell
npm run godot:open
```

这个命令会使用项目内的 SDK 编译 C#，再打开 Godot .NET 编辑器，并自动启动本地 MCP 服务。

请先保存并关闭已经直接打开的同一项目编辑器，再使用上述命令启动。直接双击 Godot 不会继承此脚本设置的本地 SDK、NuGet 缓存和 `GODOT_MCP_*` 环境；例如 2026-11-02 实测直接打开的窗口处于 Cloud 模式，而 Codex 指向本机服务器，且本机端口拒绝连接。`npm run godot:status` 可核对编辑器与服务状态。修改客户端配置后通常需要新开 Codex 会话才能重新加载工具；即使 CLI 就绪，当前会话也可能没有挂载该 MCP 工具。

2026-11-02 用户保存关闭后，通过上述命令重启成功：`godot:status` 显示 Connected；向当前 Codex 配置的本地 MCP 地址发送 initialize / tools-list / rql-query / screenshot-viewport 均成功。当前会话没有自动出现 Godot 工具，因此这次实际调用使用独立本地 MCP 客户端，不能据此声称 Codex 已自动挂载。截图是编辑器视口而非游戏画面。编译有3条插件调用旧 Dock API 的弃用警告；编辑器日志仍出现 `System.Net.Sockets.resources` 探测提示，连接成功不代表该提示已消失。

```powershell
npm run godot:build
npm run godot:status
npm run godot:cli -- --help
```

## 安装位置

- Godot .NET 编辑器：在终端通过 `GODOT_BIN` 指定，或将路径写入项目内的 `.tools/godot-editor-path.txt`。
- .NET SDK：`.tools/dotnet/`。
- NuGet 依赖及缓存：`.tools/nuget/`。
- 编辑器插件：`addons/godot_mcp/`。
- MCP 服务程序：`.godot/mcp-server/`。
- 编辑器日志：`.tools/logs/editor.log`。
- Codex MCP 配置：`.codex/config.toml`；当前项目已登记为 Codex 受信任项目。

启动脚本优先使用当前终端的 `GODOT_BIN`，再读取未提交的本地路径文件。脚本会将编辑器配套 NuGet 包复制到 `.tools/godot-nupkgs/`，供 `NuGet.Config` 读取。

MCP 仅监听本机回环地址。项目路径变化时，应重新生成 MCP 配置；本地服务端口和项目路由由项目路径计算得到。新增配置后，重新打开本项目的 Codex 会话。

SDK 的环境变量通过启动命令传给子进程。为确保编辑器构建时使用项目内 SDK，使用 `npm run godot:open` 启动本项目。
