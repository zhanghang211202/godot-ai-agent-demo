# Godot 项目动画审查与改进方案

> 2026-11-07 后续：用户决定暂不增加复杂咏唱规则，优先打磨平衡与动作。法师新增挥杖和手势施法两套四姿势，使用 `mage_cast_timeline.tscn` 的 AnimationPlayer 分别控制；MCP 读取了三个动画及新增关键帧。实际战斗与图像检查见[日语记录](devlog/2026-11-07-mage-balance-motion.ja.md)。新图仍是离散姿势，连续中间帧和人体质量仍需进一步人工检查。

> 同日修正：收到不同动作人物大小不一致的反馈后，依据各帧帽顶与脚底调整人物比例和法术发射点；实际画面对照见[日语记录](devlog/2026-11-07-mage-scale.ja.md)。

> 目标项目：`<PROJECT_DIR>`
>
> 创建日期：2026-10-29；审查日期：2026-11-02
>
> 状态：2026-11-02 已完成审查并接入法师受击 PoC；2026-11-03 实测本地 MCP 操作 AnimationPlayer，结果见第九节。下方第三至第五节保留审查时的基线记录。

## 一、目标

在保留现有美术资产与核心玩法的前提下，找出当前 motion / 动画表现不足的具体原因，判断能否用 **Godot MCP + AnimationPlayer** 改善，并提出可最小风险落地的方案。

**边界：先审查、先报告，不要直接大规模重构。** 首轮仅更新本文件；如需安装插件、修改场景、改动资源、调整输入或导出设置，先列出变更清单与风险，再取得确认。不要覆盖现有 `AGENTS.md` 或其他用户文档。用户随后另行要求游戏日语化，该工作独立于动画 PoC。

## 二、给本地 Codex 的任务

请在 `<PROJECT_DIR>` 项目根目录执行以下工作：

1. 确认项目根目录存在 `project.godot`。记录 Godot 版本（从 `config/features`、当前环境可执行文件版本和项目配置中确认；如果无法确认就明确注明）。先检查 `git status`，不要覆盖用户未提交的修改。
2. 梳理目录结构、入口场景、角色场景、UI、特效、动画素材与相关 GDScript。重点搜索 `.tscn`、`.tres`、`.gd`、`addons/`、`assets/` 以及所有常用的 2D/3D 图像和模型资源。
3. 找出所有已有的 `AnimationPlayer`、`AnimationTree`、`AnimatedSprite2D`、`SpriteFrames`、`Skeleton2D`、`Bone2D`、Tween / `create_tween()`、shader 动画和脚本插值逻辑。说明每套系统目前控制什么、在哪个场景中使用、能否复用。
4. 选 1–3 个最影响观感的动作/场景，指出问题是素材不连续、关键姿势不够、插值/缓动不佳、状态切换生硬、时间安排欠妥、视觉反馈不足，还是角色骨骼/分层不适合。
5. 根据**实际现有资源**，评估以下三条路线：
   - A：现有 Sprite2D/Node2D + AnimationPlayer，制作 transform、opacity、shader 参数、局部节点的可复用动画。
   - B：现有逐帧图 + AnimatedSprite2D/SpriteFrames，必要时增加 AnimationPlayer 做辅助特效。
   - C：需要分层素材/骨骼的角色 + Skeleton2D/Bone2D + AnimationPlayer；仅在资源允许时推荐。
6. 检查是否已安装 MCP 插件、是否具备兼容的 Godot 版本。只有确定适配与收益后，再推荐一个具体 MCP 方案。优先考察是否可以查看场景树、操作 AnimationPlayer 轨道与关键帧、查看运行画面和报错。记录插件来源、版本要求、可能的网络/执行权限风险，不要自行安装。
7. 将**实测结果**写入本文件的“项目实况”“问题优先级”“方案判断”“实施步骤”四部分，并给出明确的证据路径（例如 `res://scenes/player.tscn`、脚本、节点）。不要把推测写成已发现的事实。
8. 只建议一个低风险的 PoC（概念验证），例如挑一个角色的 idle/walk 或一个 UI 弹出动效；写明涉及文件、实现方法、测试方式、验收标准、回滚方式。**首轮不要直接执行 PoC，等待用户批准。**

## 三、项目实况

| 项目 | 实测结论 | 证据/路径 |
|---|---|---|
| Godot 版本 | 项目特性为 4.7、C#、GL Compatibility；本机运行输出为 `4.7.2.stable.mono.official.ed1daf0bf`；项目内 .NET SDK `8.0.426`。只验证本机 Windows 环境。 | `project.godot`、`scripts/godot.mjs`、`npm run game:mage:discovery:test` 启动输出、`.tools/dotnet/dotnet.exe --version` |
| 主场景和类型 | 默认入口是 2D Control 原型 `main.tscn`；当前优先的法师可通过 `npm run game:mage` 启动 `mage_trial.tscn`，不是默认入口。场景根节点很薄，界面与战斗节点由 GDScript 动态创建。还有职业试验和角色概念查看场景。 | `project.godot`、`scenes/main.tscn`、`scenes/mage_trial.tscn`、`scenes/class_lab.tscn`、`scenes/character_review.tscn`、`scripts/classes/class_lab.gd` |
| 角色与素材 | 法师静态透明 PNG 和单独 2×2 四姿势施法图集；三种敌人各有四姿势图集。按 alpha 边界裁切并逐帧记录脚点；魔法图标也是图集。现有角色是合成好的整张身体与法杖，没有发现可绑定的身体分层或骨架；四姿势不等于连续动作帧。 | `assets/art/c1-static-v1/characters/mage-idle.png`、`assets/art/c1-motion-v1/characters/mage-cast.png`、`assets/art/mage-trial-v1/enemies/moon-sentinel.png`、`assets/art/mage-expansion-v1/enemies/`、`scripts/classes/class_motion.gd`、`scripts/classes/mage_art.gd` |
| 当前动画方案 | 搜索场景和项目脚本未发现现有 AnimationPlayer、AnimationTree、AnimatedSprite2D、SpriteFrames、Skeleton2D、Bone2D 或 Tween；插件内部出现的类名不代表游戏在用。法师按事件使用 idle/windup/impact/recover 四态，0.16 秒进入 recover、0.42 秒回 idle；`class_arena.gd` 每次绘制更新 Sprite2D 的图集区域、位置、比例和 shader。命中/退场有单独计时器，敌人同样按状态选帧。法术轨迹和护盾由 CanvasItem 绘制、插值和时间驱动；shader 处理受击着色、透明度与边缘。旧版也在脚本中绘制及插值。 | `scripts/classes/class_motion.gd`、`scripts/classes/class_arena.gd`、`scripts/classes/class_feedback.gd`、`scripts/classes/mage_effects.gd`、`scripts/classes/mage_shield.gd`、`scripts/classes/class_actor.gdshader`、`scripts/gameplay/main.gd` |
| 运行画面证据 | 历史原生 Godot fixture GIF 能看到施法、命中和退出；这是自动配置的运行画面，不能代替玩家盲测。 | `docs/devlog/screenshots/c1-motion-v1/mage-motion.gif`、`docs/devlog/screenshots/mage-expansion-v1/moth.gif`、对应 `manifest.json` |
| MCP / 插件 | 已安装并启用 IvanMurzak Godot-MCP `0.31.0`；项目配置符合其公开要求的 Godot 4.3+ .NET 与 .NET 8。2026-11-02 用户保存并关闭直接启动的 Cloud 模式编辑器后，使用 `npm run godot:open` 重启；`godot:status` 和 MCP 协议实际请求均成功。通过配置的本地 MCP 路由发现15个工具，`rql-query` 只读查询得到 `Emberpack / Control / res://scripts/gameplay/main.gd`；`screenshot-viewport` 返回有效 PNG，但它是编辑器中的空白2D视口，**不是游戏运行画面**。当前 Codex 会话仍未挂载 Godot 工具，此次通过项目内 CLI 和独立 MCP 客户端验证。尚未实测轨道编辑或运行时错误读取；`godot-demo.csproj` 没有 Animation Tools 扩展引用。 | `addons/godot_mcp/plugin.cfg`、`project.godot`、`addons/godot_mcp/extensions.catalog.json`、`godot-demo.csproj`、`scripts/godot.mjs`、`MCP_SETUP.md`、[验证记录](devlog/2026-11-02-mcp-connection.ja.md)；[项目官方要求](https://github.com/IvanMurzak/Godot-MCP#requirements) |
| 审查前未提交变更 | `package.json`、`class_grid.gd`、`class_lab.gd` 有未提交修改；`mage_recipe_guide.gd`、`test_mage_discovery.gd` 及本计划未跟踪。另有用户本地图像及编辑器生成的 `.import`/`.uid`，不纳入版本提交。配方开发测试当时为 109 项、2 项拖放模拟失败，属未完成工作；不将其当作动画结论。 | `git status --short`、`tests/test_mage_discovery.gd` |

## 四、问题优先级

| 优先级 | 现象与原因 | 对应文件 | 改进建议 | 预计范围 |
|---|---|---|---|---|
| P1 | 施法有 4 个离散整身姿势，没有中间过渡；动作按事件突变，同一法师动作共用于多种魔法。逐帧图的细节和轮廓限制了仅靠插值的改善。 | `class_motion.gd`、`mage-cast.png`、`class_arena.gd` | 保留既有事件和脚点；先验证可独立控制的局部 presentation 层，之后再评估补画中间姿势。 | 单独 PoC，后续才考虑素材扩充 |
| P1 | 受击目前是 shader 着色与整身水平振动；退场主要透明度变化，缺少专门的受击/退场姿势。视觉观察基于历史 fixture，程度仍需人眼复核。 | `class_feedback.gd`、`class_arena.gd`、`class_actor.gdshader` | 先用不改变战斗结果的表现层试验短暂位移/颜色曲线；复杂肢体反应需新素材。 | 仅表现层 |
| P2 | 现有 Sprite2D 属性每次重绘都被脚本写入，直接对同一位置/scale/region 使用动画轨道会产生覆盖或抖动；法术/护盾计时也受暂停和倍速控制。 | `class_arena.gd:85`、`:236`、`mage_effects.gd` | 动画只控制独立子节点或包装节点，并明确唯一写入者；不要改变真实命中时点、暂停及速度。 | 不调整战斗规则 |

## 五、方案判断

- **A，Sprite2D/Node2D + AnimationPlayer：推荐作为可选表现层 PoC。** 对独立节点的 transform、modulate 或 shader 参数做可编辑曲线，避免与 `class_arena.gd` 的逐帧布局写入同一属性。它可以改善节奏，却不能凭空增加肢体关键姿势。Godot 的 [AnimationPlayer 文档](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)说明其适合复杂时间曲线。
- **B，AnimatedSprite2D/SpriteFrames：后续可考虑，但不要求迁移。** 现有图集有每帧不等边界、脚点和施法点；等分图集直接切换会错位。若迁移，须保留每帧脚点/武器、事件同步及多次命中去重，先与当前脚本比较。四姿势本身不会因节点类型变化变流畅。[官方 2D 动画文档](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html)支持图集与逐帧两种方式。
- **C，骨骼：目前不推荐。** 当前无可用的躯干、头、手、法杖等独立层或骨架，整图摆动不能解决遮挡和手部质量；需要重新制作分层并验证像素变形后再评估。
- **MCP + AnimationPlayer：条件性适合。** 优先保留现有 [IvanMurzak Godot-MCP](https://github.com/IvanMurzak/Godot-MCP)，无需另装第二个 MCP。本次已验证本地协议连接、只读场景查询和编辑器截图；查询、修改、截图工具均出现在工具列表，但没有实测修改或游戏运行时错误捕获。[Animation Tools 官方说明](https://github.com/IvanMurzak/Godot-MCP/blob/main/extensions/Godot-AI-Animation/README.md)列出可选扩展 1.1.1 的轨道/关键帧能力，要求 4.3+ C# 与支持 RQL 的核心版本；本项目尚无该扩展的包引用，不能声称轨道 API 已可用。根据 PoC 需要再决定是否安装；本轮不安装。
- **安全边界：** `scripts/godot.mjs` 以本地 loopback 和无认证启动自定义 MCP；仅在可信本机使用，不对外开放。工具可能读写项目、执行代码或暴露日志；开放更广网络前应配置认证并审阅权限。不要把未连接的工具或文档中声称的功能写成实测成功。

## 六、第一阶段 PoC（已实施，2026-11-02）

用户随后明确要求继续完善法师和动画。本轮用独立 `res://scenes/components/mage_hit_motion.tscn` 的 AnimationPlayer 制作受击时间线，再以包装节点接入法师；原 Sprite2D 的图集区域、位置和比例仍由 arena 控制，骑士原受击方式保留。受击依据真实 `enemy_attack` 事件，同一步多段合并一次，动画通过手动时钟跟随暂停和倍速。法盾和相关施法起点随包装节点位移。五个像素对齐的水平位置在0.22秒内恢复到原点，不新增身体/手臂姿势，也不改变伤害或命中时刻。

独立及实战自动化验证、三种窗口截图、对照规则引擎和录制限制见[日语开发记录](devlog/2026-11-02-mage-rehearsal.ja.md)。当时 MCP 服务器不可达，PoC 用项目本地 Godot 实施，没有通过 MCP 编辑关键帧；无需安装 Animation Tools 扩展。下方保留最初建议，作为实施前的参照。

- **目标：** 法师战斗中的短暂受击反馈；保留现有 shader 和事件驱动，比较同一次受击前后效果。
- **拟涉及文件：** 新增独立 `res://scenes/poc/mage_hit_feedback.tscn` 和 PoC 专用脚本/动画资源，复用法师静态图；先不改 `class_arena.gd` 或运行入口。之后若获准集成，才添加包装节点并调整表现层接口。
- **轨道与时间线：** 在独立的 `Node2D` 包装节点上用 AnimationPlayer 做约 0.16 秒短位移及恢复的关键帧，首尾归零、像素取整；可选独立 modulate 轨道。具体位移和缓动需在运行时调校。不要写入 arena 负责的 sprite 位置、region 或 shader 参数。
- **连接方式：** PoC 用模拟受击事件触发一次，重复受击与暂停/1×/2×有明确策略；正式集成时只订阅已有 `ClassBattle` 事件，伤害和时序仍由现有规则负责。
- **新素材：** 无；不能由此证明身体动作质量提升。
- **验证：** 用 `scripts/godot.mjs` 启动独立场景；记录实际运行画面，检查循环恢复、连续受击、暂停及倍速，并运行 `npm run game:classes:test`、`npm run game:classes:art:test`、`npm run game:mage:vfx:test` 等相关回归。比较修改前后 GIF；保持 fixture 标注。
- **验收：** 可看清受击但脚点不漂移；播放完精确恢复、重复命中不累积位移；暂停/倍速行为正确；不改变 HP、事件时刻、存档与画面布局，无新增运行错误。主观流畅度须人工观看，不能只凭通过测试宣称。
- **回滚：** 独立场景/脚本可直接移除；原场景、图像与动画系统不覆盖。

## 七、实施步骤与风险

1. 完成项目审查与记录；用户随后要求继续开发动画。
2. MCP 此次不可达，因此使用项目本地 Godot 验证 PoC，没有安装扩展或重启用户的编辑器。
3. PoC 的包装节点已接入法师并做自动回归；GIF 为人工步进动画的受控实机帧，尚需人眼试玩评价。
4. 只有在需要更复杂肢体动作时，规划新逐帧或分层素材；不覆盖角色原图、批量改路径或改变输入/碰撞/战斗规则。

第三方插件可能获得文件和执行权限；编辑器配置、凭据和玩家存档不得提交。不要将生成关键帧等同于动画质量提高，也不要将概念图或人工组合图冒充运行截图。

## 八、参考资料

- Godot 官方 [2D Sprite animation](https://docs.godotengine.org/en/stable/tutorials/2d/2d_sprite_animation.html) 和 [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html)。
- 已安装插件：[IvanMurzak/Godot-MCP](https://github.com/IvanMurzak/Godot-MCP)；[Animation Tools 扩展](https://github.com/IvanMurzak/Godot-MCP/blob/main/extensions/Godot-AI-Animation/README.md)。
- 原备选：[godot-mcp2](https://github.com/Mobuis/godot-mcp2)、[Funplay Godot MCP](https://store.godotengine.org/asset/funplay/funplay-godot-mcp/)。本轮未安装，也未声称已验证其兼容性。

## 九、MCP 与 AnimationPlayer 实测（2026-11-03）

编辑器原先处于 Cloud 模式且本地服务未启动；在不关闭编辑器的情况下切换为 Custom，启动已安装的本地服务并重新配置项目客户端。本地 MCP 协议握手成功，发现15个工具；RQL 打开 `res://scenes/components/mage_hit_motion.tscn`，查询到 `MageHitMotion` 和 `AnimationPlayer` 节点，原 `main.tscn` 保持在另一标签页。随后以 MCP 的 `script-execute` 读取实际 `hit` 动画：0.22 秒、1 条 `.:position` 轨道、5 个关键帧。

以 MCP 在该 Animation 的**内存深拷贝**上把第二个关键帧从 `(-5, 0)` 改为 `(-6, 0)` 并恢复；原动画仍为 `(-5, 0)`。这验证了经 MCP 调用 Godot API 读取和修改关键帧，但没有保存生产动画的修改，也没有验证可选 Animation Tools 扩展或运行游戏的 MCP 错误采集。此前 PoC 仍是直接通过项目 Godot 工具制作，不能追述成由 MCP 制作。当前 Codex 会话的工具列表未动态出现 Godot MCP；此次实际调用使用项目内独立 MCP 客户端和本地 HTTP 工具接口。[实测记录](devlog/2026-11-03-mcp-mage-analysis.ja.md)。

同日后续新增 `res://scenes/components/mage_cast_timeline.tscn`，用独立 AnimationPlayer 的四个姿势关键帧衔接蓄力、释放与收势；飞行开始时而不是命中时切换释放姿势。实际命中仍由规则事件产生，同步策略、同发/近邻施法、取消和战斗一致性测试见[日语记录](devlog/2026-11-03-mage-cast-sync.ja.md)。通过本地 MCP 打开该场景并读取 AnimationPlayer 的1条轨道和4个键；场景文件本身由常规项目编辑创建。它沿用已有四帧，不代表完成新肢体动画。
