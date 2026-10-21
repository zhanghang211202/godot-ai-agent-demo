# 《靠装勇者：背包合成 RPG》参考研究

研究日期：2026-10-20。目标是提取背包策略的可玩结构，供本项目首个原创 Godot Demo 使用。

## 已直接确认的体验

- 官方将游戏定义为像素风 Roguelike 自动战斗 RPG：先通过背包配置建立战斗能力，再观看英雄自动使用装备战斗。装备布局会影响协同效果。[官方 Google Play 页面](https://play.google.com/store/apps/details?hl=en&id=com.fiveminlab.overgeared.hero.backpack.merge)
- 官方首页强调背包装备合成与短节奏地下城战斗。[官方站](https://overgeared.app/)
- 用户提供的 Wiki 区分勇者、宠物、武器、道具和合成配方，英雄又分战士、游侠、魔法师。[塔塔王国 Wiki](https://tatakingdom.tw/zh-TW/games/overgeared-hero)

## YouTube 实机观察

参考视频：[Overgeared Hero: Merge RPG - Gameplay Walkthrough part 1 (iOS, Android)](https://www.youtube.com/watch?v=9WkzU8AMfuQ)。另找到 [Overgeard Hero: Merge RPG](https://www.youtube.com/watch?v=OiVQdJ-XikI)。

实际查看了第一条视频由 YouTube 提供的三张 storyboard，每张 3 × 3 帧，覆盖约 0:00–1:20、4:30–5:50、12:00–13:20 的十秒采样帧；没有下载整段视频。因为是低分辨率采样，不能据此声称已逐帧确认教程文字或合成时机。

直接可见：

- 手机竖屏构图，紫黑色面板和细边框；英雄和敌人在上方横向对峙；背包与商店在下方。
- 战斗会出现伤害数字、斩击和法术效果。战斗之后回到可整理背包的商店阶段。
- 武器和道具使用清晰、色彩饱和的低分辨率像素图标。剑以长条形状占据多格；小素材是单格。
- 原有剑经过合成后变成金色更醒目的剑，随后继续带入战斗。后期背包塞入更多不同形状的物品。
- 图标有选中轮廓和悬浮信息窗，背包布局在战斗中仍然可见，便于把装备和输出联系起来。

以上是画面观察；购买金额、拖动具体操作和精确帧级触发时间没有从这些小图中读出。

## Wiki 可核对的具体设计

| 项目 | 明确记录 | 对 Demo 的启发 |
| --- | --- | --- |
| [练习用的剑](https://tatakingdom.tw/zh-TW/games/overgeared-hero/weapons/warrior-trainingsword) | 占 2 格；可与不同石头合成为不同剑 | 合成不能仅有相同物品升级，应包含分支配方 |
| [研磨石](https://tatakingdom.tw/zh-TW/games/overgeared-hero/items/warrior-smithingstone) | 占 1 格，有左右两个协同蓝点；能与练习剑合成长剑 | 明确标示加成方向比隐藏邻接规则更易理解 |
| [长剑](https://tatakingdom.tw/zh-TW/games/overgeared-hero/weapons/warrior-longsword) | 占 3 格；长剑与火把可合成为火焰剑 | 更强装备可更占空间，让升级仍有布局代价 |
| [小圆盾](https://tatakingdom.tw/zh-TW/games/overgeared-hero/items/neutral-buckler) | 占 1 格；两个可合成为木制护盾 | 同物合成是最容易在第一分钟教会的基础配方 |
| [生命值药水](https://tatakingdom.tw/zh-TW/games/overgeared-hero/items/neutral-hppotion) | 占 1 格，按冷却周期回血；两瓶可合成为更大药水 | 回血物品让玩家能选择续航路线 |
| [短剑](https://tatakingdom.tw/zh-TW/games/overgeared-hero/weapons/neutral-dagger) | 占 2 格，有四个协同点；可与多种异类材料进化 | 相同底材适合组成不同流派 |

研磨石页面 HTML 的连接预览明确把两个蓝点画在物品左右两格。其他装备有各自的连接范围，因此原作协同不应被简单描述为“全部四向邻接都有加成”。

## 核心循环与确认程度

1. 获得一轮金币和商店候选装备。
2. 在有限格子里摆放装备，旋转长条物品，保留未来合成材料；花钱刷新或购买。
3. 根据配方提升物品，同时通过正确连接位置取得协同。
4. 开始自动战斗，观察伤害、护盾、回血与攻击频率。
5. 胜利获得下一轮资源和更难的敌人，失败后重新构建。

第 2 步的购买、拖入背包、旋转、出售，以及每轮四个商店候选，在[玩家机制整理](https://loadoutgg.com/overgeared-hero/basics/)中有明确说明；官方页面只概述配置与合成。这些属于参考资料核实，不是从低清 storyboard 逐项读出的操作。

尚未直接确认：原作局内所有配方是否一律要求材料连接后经过一场战斗、合成产物如何解决额外占格，以及每个配方的精确连接规则。Demo 可自行定义“拖到目标装备上即时合成”，但应称为本 Demo 的简化规则，不能宣称完全复刻原作。

## 适合首个可玩的 Godot Demo

建议一局约 5–8 分钟，采用原创像素幻想美术和横屏桌面布局，保留“摆放产生策略、合成产生期待、自动战斗给出反馈”的体验。

- 一名英雄、一条五场战斗路线，最后一场 Boss。
- 一张有限的格子背包；完整的鼠标拖放、格子吸附、碰撞检查和 R 键旋转。
- 每轮四件商品、金币、购买、刷新、出售；无效摆放应回到原位。
- 约 8–12 件物品，以攻击、防御、回复三条路线组成可理解的选择。
- 至少一条同物升级和两条异物配方；在物品提示中直接展示配方。
- 一种明确可视化的邻接增益，例如磨刀石强化左右相连武器；拖动时显示影响格。
- 每件武器独立计时攻击，护盾和药水分别体现减伤与续航；战斗有血条、伤害飘字、命中特效和胜负反馈。
- 胜利后推进商店和下一敌人，战败或通关后可立即重新开始。

首版暂缓英雄养成、宠物培养、离线收益、账号、公会、抽卡、付费和海量配方。这些不影响验证核心玩法。

美术应优先统一图标尺寸、清楚表现装备形状、保持深色背景与装备的对比；用暖色营地和冷色森林建立本项目自己的风格，而不是逐像素复制原作界面。

## 素材来源说明

Wiki 页脚注明游戏素材权利属于原权利人。官方另有 [Fan Kit 发布公告](https://overgeared.app/en/notice/fan-kit-release-notice/)及 [Fan Kit 目录](https://drive.google.com/drive/folders/1OLMN2pthBWoV1nPhiGF7UxosAlvDFBHc)，公告允许个人非商业用途，并要求公开分享时标注其版权。当前研究只查看参考图与页面，没有把原作素材放入游戏；后续若使用，需按该公告和用户指南保留归属。
