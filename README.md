# 星火旅囊 · Emberpack

一个可玩的 Godot 像素背包合成 RPG Demo。参考《靠装勇者》的构筑循环，使用原创世界、美术和界面。

![准备阶段](docs/screenshots/prepare.png)

## 已实现

- 6×4 格背包、不同形状装备、鼠标拖放与旋转。
- 四格商店、金币、购买、刷新与出售。
- 同种同级合成、短剑与磨刀石配方、最多三级品质。
- 磨刀石/火种的邻接攻击增益、护甲、回血、药水、暴击。
- 装备独立冷却、自动战斗、伤害数字、攻击动作、音效与战况反馈。
- 五波敌人、最终 Boss、胜利奖励、失败/通关后重开。
- 中文界面、合成图鉴和操作说明。

## 本机启动

```powershell
npm run game
```

在 Godot 编辑器中打开 `project.godot`，按 **F6/F5** 也可运行主场景；F6 需要先打开 `scenes/main.tscn`。

当前本机 Godot 路径：

```text
D:\Program Files\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe
```

## 新环境准备

1. 准备 Godot 4.7.2 .NET 版和 .NET SDK 8.0.426。SDK ZIP 解压到 `.tools/dotnet/`，该目录应直接包含 `dotnet.exe`。
2. `npm ci` 安装项目内 CLI。
3. Godot 路径与上面不同时，在当前终端设置 `$env:GODOT_BIN = '你的Godot.exe路径'`。
4. 首次执行 `npm run godot:open`，让编辑器完成 C# 构建与素材导入；之后可以用 `npm run game` 直接游玩。

游戏主体使用 GDScript；C# 工程和 SDK 用于 Godot-MCP 编辑器插件。启动脚本仅为子进程设置 SDK 环境，SDK、NuGet 包和缓存保留在 `.tools/` 内；这些文件不提交到仓库。编辑器自带的 Godot NuGet 包会复制到 `.tools/godot-nupkgs/`。

## 操作

| 操作 | 输入 |
| --- | --- |
| 移动/购买 | 鼠标拖到背包；商品也可点击后再点击格子 |
| 查看装备 | 点击或悬停 |
| 旋转 | R |
| 合成 | 将同种同级装备或配方材料叠放 |
| 出售 | 选中装备后按 D / Delete，或点出售按钮 |
| 开始战斗/下一波/重开 | 空格或右下按钮 |
| 取消放置 | 右键 / Esc |
| 合成图鉴 | Tab |
| 音效开关 | M |

第一次可以先把两把短剑叠放升级，再购入护盾和月露草。战斗中背包内武器的底部金线显示冷却进度。

## 验证

```powershell
npm run game:test
```

测试包括背包合法性、金币原子性、合成空间、旋转、邻接增益、帧率独立的战斗模拟，以及通过鼠标交互购买、构筑、五波通关和重开。

首版验证结果：核心逻辑 **69 项**、界面交互 **58 项**，共 **127 项检查通过**；C# 工程构建通过。

![自动战斗](docs/screenshots/battle.png)

## 项目资料

- [Demo 计划](docs/demo-plan.md)
- [实机与 Wiki 研究](docs/reference-research.md)
- [美术方向与场景生成提示](docs/art-direction.md)
- [素材来源](docs/asset-credits.md)
- [本机 MCP 配置说明](MCP_SETUP.md)

本 Demo 简化为即时拖放合成、四向邻接和固定大小升级，不是对原作数值与规则的完整复刻。首版聚焦核心循环，尚未加入存档、长期养成、宠物和多职业。
