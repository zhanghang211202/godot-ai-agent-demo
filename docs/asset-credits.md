# 美术素材与字体出处

本 Demo 的角色、装备图标和森林场景为本项目制作。参考游戏《靠装勇者：背包合成 RPG》及其 Wiki、视频仅用于研究玩法与表现方向；项目未使用该游戏的原始美术、截图裁切、图标、角色精灵或音频素材。

| 文件 | 来源与制作方式 |
| --- | --- |
| `scripts/visuals/pixel_art.gd` | 本项目原创代码像素美术。英雄、史莱姆、哥布林、狼、树人及装备、金币、生命等图标，使用手工编写的像素矩阵与调色板，通过 Godot `Image` 在运行时生成；没有加载参考游戏素材。 |
| `assets/art/forest_background.png` | 本项目通过 OpenAI 内置 **imagegen**，根据原创场景提示生成的森林遗迹战斗背景。生成提示与美术方向记录在 [art-direction.md](art-direction.md)；不是参考游戏的原图或截图。 |
| `assets/fonts/NotoSansCJKsc-Regular.otf` | **Noto Sans CJK SC Regular**，字体内嵌版本为 **2.004**，版权声明为 **© 2014–2021 Adobe (http://www.adobe.com/)**。来源为 [Noto CJK 官方仓库中的字体文件](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf)。 |

Noto Sans CJK 字体采用 **SIL Open Font License 1.1**。仓库随附完整许可证 [assets/fonts/OFL.txt](../assets/fonts/OFL.txt)，亦可查阅 [Noto CJK 官方许可证](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE)。字体保留其独立许可证及内嵌版权信息；随项目分发时应一并保留这些信息。

## 第三方编辑器工具

`addons/godot_mcp/` 来自 [IvanMurzak/Godot-MCP v0.31.0](https://github.com/IvanMurzak/Godot-MCP/tree/v0.31.0)，采用 Apache-2.0，随附 [完整许可证](../addons/godot_mcp/LICENSE)。其 NuGet 依赖通过工程引用恢复，不包含在本仓库中。
