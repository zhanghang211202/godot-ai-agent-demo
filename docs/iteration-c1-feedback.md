# C1 战斗反馈样板 · 2026-10-27

运行 `npm run game:classes`。在[四帧动作](iteration-c1-motion.md)上增加真实命中数字、多段/护甲提示、受击闪色/轻晃和胜负淡出。保留MA／KA原动作及规则，未增加新状态、伤害、敌人机制或专用受击/倒地帧。

![实际Godot法师fixture，合法编织，数字与训练木靶淡出；无声6秒](devlog/screenshots/c1-feedback-v1/mage-feedback.gif)

![实际Godot重刃fixture，正常购买/锻造，命中与胜利反馈；无声6秒](devlog/screenshots/c1-feedback-v1/heavy-feedback.gif)

[失败片段](devlog/screenshots/c1-feedback-v1/loss-feedback.gif)为5秒实机录像。法师正常丢弃左上初始术式，保留另一个攻击来源和原84生命；未吸收新元素。结果25.20秒失败，有效输出85、承伤84、木靶剩55。不是改伤害/生命制造的假失败。

## 行为

- 数字取战斗事件的有效伤害，护甲抵挡也取事件字段，不自行用原始伤害反算。三段潮汐在同次激活合为`-15 · 3段`，规则仍保留三段命中；顶部既有事件提示沿用单段数值。
- 受击闪色和左右轻晃、木靶闪亮/轻晃、命中环是代码反馈。胜利木靶倾斜淡出，真实战败主角淡出；超时不会将尚活着的角色画成死亡。原姿势加闪色/位移/透明度不计作新的逐帧动作。
- 数字存活0.90秒、受击0.26秒、淡出0.70秒，均为表现时长。战斗立即按规则结算，淡出不增加summary耗时。战中暂停冻结数字、受击与动作，1×／2×使用同一个倍率；结果时沿用当前倍率，暂停按钮仍按原流程禁用。
- 瞬时数字最多24条、事件去重保留最近64个ID；每侧实际画最新3行，避免长帧批量事件遮挡人物或HUD。过期提示释放；完整伤害始终以来源复盘为准。
- 新职业、读档、恢复战前和新战开始重置数字、受击、淡出和去重。木靶消失后恢复战前会正常重现，没有写入存档的表现状态。

## 像素整理的实际结果

三次内置imagegen重绘试验均未通过，未替换游戏原图。法师低alpha画素增加，长剑的面部/材质简化过度，重刃的杂边/帧间问题改善不足。[不采用记录、原PNG、测量和逐字提示](concepts/2026-10-26-pixel-cleanup/README.ja.md)单独保存为生成试验，不能当成实机或生产素材。

本轮改为在独立的角色`Sprite2D`上使用`class_actor.gdshader`：alpha<0.5不绘制，保留像素的内部为不透明，受击闪色和结算淡出另用uniform控制。背景和UI不应用此Shader。1280×800相同准备姿势的开关对比有11,324个不同像素，变化矩形为`(254,154,149,188)`，只落在角色范围。原PNG的alpha、RGB、色数及尺寸未改；RGB杂边、源逻辑格子、逐帧体形与刚性武器长度仍未修复。

![实际1280×800三段提示，最新数字分行，不覆盖角色面部](devlog/screenshots/c1-feedback-v1/mage-multi-hit-1280x800.png)

## 验证

| 执行 | 结果 |
| --- | --- |
| `npm run game:classes:test` | Run96 + Battle143 + Save269 + UI115 = 623，失败0 |
| `npm run game:classes:art:test` | 静态兼容142 + 文字146 + 动作264 + 新反馈62 = 614，失败0 |
| `npm run game:classes:feedback:render:test` | 真实OpenGL／GPU读回6，失败0 |
| `node --check scripts/godot.mjs` | 退出0 |

合计**1243项、失败0**。保存负例有两次已知`Exponent too high`警告，拒绝与状态保持通过。新反馈覆盖三种胜利配置和合法失败配置、独立Battle逐字段结果一致、真实受击暂停/倍速、重置、去重、过期及内存上限。GPU读回用32×8的程序测试纹理，不是游戏截图：关闭过滤时alpha64/128约为0.251/0.502，打开后为0/1；alpha254保持为1，淡出0.5也通过。

| 配置 | 结果 | 规则耗时 | 有效输出 / 承伤 |
| --- | --- | --- | --- |
| 法师合法编织 | 胜 | 8.60秒 | 140 / 24 |
| 骑士重刃 | 胜 | 11.00秒 | 140 / 36 |
| 骑士初始长剑（自动检查） | 胜 | 21.35秒 | 140 / 66 |
| 法师丢弃一个初始术式 | 败 | 25.20秒 | 85 / 84 |

前三者与原规则一致。旧森林/保存/目录原图未改，不重跑旧森林949项或C#构建。仍只验证本地Windows／Godot4.7.2.NET／OpenGL兼容，独立导出与其他平台未验证。

## 证据与复现

[不可变清单](devlog/screenshots/c1-feedback-v1/manifest.json)包含36PNG、3GIF、三份实机配置/结果JSON、反馈测试JSON和GPU读回JSON。生成试验放在concepts，实际游戏画面放在本版截图目录；玩家保存禁用，全部配置使用正常有限API。

三段Movie Maker源录像固定16FPS，总帧法师166、重刃204、失败432。发布GIF分别取帧70～165、108～203、352～431，缩至720×480，无声，6/6/5秒；不是性能测量。录像之后补了拥挤时每侧最新3行的上限，并用最终1280场景再确认。失败录像的详情补充文案仍为较早版本，最终界面明确“专用姿势待制作”。

复现请先创建新目录`.tools/new-feedback/movie/`：

```powershell
node scripts/godot.mjs class-capture --resolution 1440x960 --fixed-fps 16 --write-movie .tools/new-feedback/movie/frame.png -- --class=mage --capture-dir=D:/WorkSpace/godot-demo/.tools/new-feedback --auto-quit
```

失败配置加`--capture-loss`（法师限定），重刃改`--class=knight`。alpha对照仅准备截图加`--capture-prepare-only`，关闭过滤另加`--compare-original-alpha`。输出目录必须未含旧证据，同名PNG拒绝覆盖。

下一步继续整理真正的源像素、透明RGB边缘、人体/武器跨帧一致性，再制作专用待机/受击/退场及训练敌人美术。当前只有事件反馈接口，完整RV-02/03/04与C1仍待验收；新机制、其余四路线与职业五战仍属后续范围。
