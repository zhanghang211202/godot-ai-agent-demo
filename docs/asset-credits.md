# 美术素材与字体出处

本 Demo 的角色、装备图标和森林场景为本项目制作。参考游戏《靠装勇者：背包合成 RPG》及其 Wiki、视频仅用于研究玩法与表现方向；项目未使用该游戏的原始美术、截图裁切、图标、角色精灵或音频素材。

| 文件 | 来源与制作方式 |
| --- | --- |
| `scripts/visuals/pixel_art.gd` | 本项目原创代码像素美术。英雄、史莱姆、哥布林、狼、树人及装备、金币、生命等图标，使用手工编写的像素矩阵与调色板，通过 Godot `Image` 在运行时生成；没有加载参考游戏素材。 |
| `scripts/visuals/pixel_art_v03.gd`、`assets/art/v03/` | 原创代码像素美术样板：主角与苔团各 14 帧、剑盾磨刀石的缩略图及占格图。PNG 由代码导出，原生绘制与导出一致；资源和 SHA-256 见 [manifest](../assets/art/v03/manifest.json)。其余装备和敌人明确登记为旧素材占位。 |
| `scripts/ui/forest_stage.gd`、`assets/art/v03/environments/forest/stage.png` | 本轮原创代码绘制的 512×144 森林舞台，限定调色板、固定独立随机源，运行时缓存；层次合成为一张，没有使用原作或外部图片。 |
| `scripts/ui/ember_theme.gd` | 本轮原创代码绘制的皮革、纸张、铜件与按钮样式。 |
| `assets/art/forest_background.png` | v0.1/v0.2 采用的原创 **imagegen** 森林背景；保留供历史对比，当前样板使用上面的代码森林。生成提示保留在 [art-direction.md](art-direction.md) 附录；不是参考游戏的原图或截图。 |
| `assets/fonts/NotoSansCJKsc-Regular.otf` | **Noto Sans CJK SC Regular**，字体内嵌版本为 **2.004**，版权声明为 **© 2014–2021 Adobe (http://www.adobe.com/)**。来源为 [Noto CJK 官方仓库中的字体文件](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf)。 |

Noto Sans CJK 字体采用 **SIL Open Font License 1.1**。仓库随附完整许可证 [assets/fonts/OFL.txt](../assets/fonts/OFL.txt)，亦可查阅 [Noto CJK 官方许可证](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE)。字体保留其独立许可证及内嵌版权信息；随项目分发时应一并保留这些信息。

## 角色外观概念 · 2026-10-24

`docs/concepts/2026-10-24-characters/` 的六张PNG由内置 **imagegen** 按本项目法师与H骑士方向分别生成，保留原始alpha，用于外观比较。它们不是战斗精灵、动画表或游戏实机截图。[完整提示集](concepts/2026-10-24-characters/prompts.json)、[尺寸与SHA-256](concepts/2026-10-24-characters/manifest.json)、[审查与限制](character-design-review.md)一并保存。旧A/H概念只作项目方向参考，用户两张图鉴仅作像素工艺参考，原图及其导入文件未随仓库公开。

## 第三方编辑器工具

`addons/godot_mcp/` 来自 [IvanMurzak/Godot-MCP v0.31.0](https://github.com/IvanMurzak/Godot-MCP/tree/v0.31.0)，采用 Apache-2.0，随附 [完整许可证](../addons/godot_mcp/LICENSE)。其 NuGet 依赖通过工程引用恢复，不包含在本仓库中。
