# Godot MCP

当前项目使用 Godot-MCP 0.31.0、本地 GameDev-MCP-Server 9.2.13 和 .NET SDK 8.0.426。

## 启动

在项目根目录运行：

```powershell
npm run godot:open
```

这个命令会使用项目内的 SDK 编译 C#，再打开 Godot .NET 编辑器，并自动启动本地 MCP 服务。

```powershell
npm run godot:build
npm run godot:status
npm run godot:cli -- --help
```

## 安装位置

- Godot .NET 编辑器：`D:\Program Files\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe`。
- 原标准版备份：`D:\Program Files\Godot_v4.7.2-stable_win64.exe.standard-backup-20261020`。
- .NET SDK：`.tools/dotnet/`。
- NuGet 依赖及缓存：`.tools/nuget/`。
- 编辑器插件：`addons/godot_mcp/`。
- MCP 服务程序：`.godot/mcp-server/`。
- 编辑器日志：`.tools/logs/editor.log`。
- Codex MCP 配置：`.codex/config.toml`；当前项目已登记为 Codex 受信任项目。

编辑器路径已按用户最新目录更新，也可以用当前终端的 `GODOT_BIN` 指定其他路径。启动脚本会将编辑器配套 NuGet 包复制到 `.tools/godot-nupkgs/`，供 `NuGet.Config` 读取。

MCP 通过 `http://127.0.0.1:25527/mcp/p/c73d34f0` 连接本项目，仅监听本机回环地址。项目路径变化时，应重新生成 MCP 配置；本地服务端口和项目路由由项目路径计算得到。新增配置后，重新打开本项目的 Codex 会话。

SDK 的环境变量通过启动命令传给子进程。为确保编辑器构建时使用项目内 SDK，使用 `npm run godot:open` 启动本项目。
