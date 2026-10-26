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

## C1 静态角色与背景 · 2026-10-26

`assets/art/c1-static-v1/` 中三张战斗站姿与两张职业背景使用内置 **imagegen** 分别生成。角色以本项目已选MA／KA原创概念作身份参考，重新绘制姿态；没有裁切旧概念板或用户图鉴。原PNG保持生成结果，[完整提示集](../assets/art/c1-static-v1/prompts.json)与[原始尺寸／alpha／SHA-256](../assets/art/c1-static-v1/manifest.json)一并保存。它们已接入本地原生职业场景，仍是待整理像素网格、色阶与透明边缘的静态候选，不含逐帧动画。舞台前景地面、接触阴影与标明占位的训练木靶由本项目代码绘制。

## C1 四帧动作 · 2026-10-26

`assets/art/c1-motion-v1/` 的三张专用动作图集由内置 **imagegen** 生成及编辑，以项目MA／KA人设和静态姿态为身份参考。它们是为四帧动作专门绘制的图集，不是旧概念裁切。原PNG保持生成alpha；Godot使用独立源区域、统一组倍率和脚底锚点播放。[提示与留存范围](../assets/art/c1-motion-v1/prompts.json)、[实际尺寸／alpha／SHA-256及限制](../assets/art/c1-motion-v1/manifest.json)均保存。法师早期逐字提示未完整留存，清单明确区分保留下来的规格摘要与本轮逐字编辑提示。用户指出的手部与法杖裁图只用于定位问题，未公开用户临时截图或私有参考图。运行GIF来自Godot实际帧，按16FPS固定录制、整数最近邻缩小与GIF量化；不是把生成图直接拼成运行证明。

## 第三方编辑器工具

`addons/godot_mcp/` 来自 [IvanMurzak/Godot-MCP v0.31.0](https://github.com/IvanMurzak/Godot-MCP/tree/v0.31.0)，采用 Apache-2.0，随附 [完整许可证](../addons/godot_mcp/LICENSE)。其 NuGet 依赖通过工程引用恢复，不包含在本仓库中。
