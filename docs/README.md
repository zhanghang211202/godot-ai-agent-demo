# 多职业背包构筑 RPG 文档入口（新标题待定）

默认 `npm run game` 为 **v0.3森林美术样板（M1-A/B）**。运行 `npm run game:classes` 可玩[C0规则](iteration-c0-rules.md)上的[C1四帧动作样板](iteration-c1-motion.md)：MA施法、KA长剑／重刃，实际事件、暂停与倍速同步，两套背景、地面与真实一战。受击／退场、专用敌人／物件和完整六路线仍待完成；旧森林与存档保持兼容。

2026-10-23 后续决策：**背包仍是核心，不同角色有独立职业玩法、资源获取与背景，每角色至少三种构筑。初期魔法师＋H近战骑士，炼金术士后续。** [职业与流派设计](classes-and-builds.md)细化六条首批路线；C0只实现其中两条的首原型，其他机制仍为计划。16-bit fantasy / tactical RPG角色细节是美术目标。[八案](art-style-exploration.md)与[离线对照页](concepts/2026-10-23/index.html)保留为早期探索。

## 当前开发基线

| 文档 | 用途 |
| --- | --- |
| [C1四帧动作实际交付](iteration-c1-motion.md) | 三组动作、事件时序、暂停倍速、实际GIF与源图限制 |
| [C1静态美术实际交付](iteration-c1-static-art.md) | 三姿态、两背景、武器对应、实机截图、检查与待修画面问题 |
| [首发角色外观基准](character-baselines.md) | 用户已选MA月庭礼装＋KA旌旗长枪；采用特征、武器适配与专用素材任务 |
| [双职业六套人设比较](character-design-review.md) | 全身／细节／缩小轮廓、离线页与 Godot 审稿台；保留六案与实际不足 |
| [产品需求](requirements.md) | 目标体验、现状差距、内容预算、FR/NFR、验收与不做范围 |
| [C0实际交付](iteration-c0-rules.md) | 原生规则实验入口、操作、检查、实机fixture与限制 |
| [C0规则契约](class-prototype-contract.md) | 本轮资源、物件、配方、固定时序、事件和独立存档 |
| [职业与流派设计](classes-and-builds.md) | 法师/骑士各三路线、资源来源、空间取舍、战斗与兼容边界 |
| [开发计划](development-plan.md) | 里程碑、工作拆分、依赖、验证、风险和下一步任务 |
| [美术规格](art-direction.md) | 现状截图审计、像素比例、色板、资产清单、动作与验收 |
| [美术与设定探索](art-style-exploration.md) | 八个工作名、主角、背景、构筑器具与概念配图 |
| [多职业美术计划](art-retheme-plan.md) | 两职业造型比较、独立背景、准备界面与实机验收 |
| [参考研究](reference-research.md) | Wiki、官方资料、三条 YouTube 实机采样证据及其限制 |
| [素材来源](asset-credits.md) | 当前已使用素材的制作方式、来源和许可 |

目标顺序：**C0 职业规则与接口 → C1 双职业各一流派的一战切片 → C2 各三流派五战 → C3 教学、平衡与 Windows 交付**。C1 不代表完整初期 Demo，旧单英雄版本预算不套用为新职业总量。

## 开发过程与博客素材

- [日语开发日志和版本截图](devlog/README.ja.md)
- [施法・長剣・重刃の四コマを実戦へ（日语）](devlog/2026-10-26-c1-motion.ja.md)
- [双职业静态美术接入与修正（日语）](devlog/2026-10-26-c1-static-art.ja.md)
- [A＋A 外观选定反映（日语）](devlog/2026-10-25-character-selection.ja.md)
- [六套人设与原生审稿台记录（日语）](devlog/2026-10-24-character-studies.ja.md)
- [C0双职业可玩原型记录（日语）](devlog/2026-10-24-class-rules.ja.md)
- [双职业需求整理记录（日语）](devlog/2026-10-23-dual-class-planning.ja.md)
- [精细像素设定探索记录（日语）](devlog/2026-10-23-art-exploration.ja.md)
- [本轮美术样板开发记录（日语）](devlog/2026-10-22-art-sample.ja.md)
- [本轮需求整理记录（日语）](devlog/2026-10-21-planning.ja.md)
- [日语博客草稿](blog/emberpack-making-of.ja.md)

截图目录保留各版本实机画面；未来概念稿或新资产提案需要另标，不能覆盖历史截图，也不能作为实装完成证明。

## 已完成版本的历史资料

- [v0.1 首个 Demo 计划](demo-plan.md)：首版范围和当时的简化，包含已被后续版本调整的规则。
- [v0.2 迭代范围与验收](iteration-02.md)：12 装备、方向协同、祝福与存档的完成记录。
- [启动与操作](../README.md)
- [本机 MCP 配置](../MCP_SETUP.md)
