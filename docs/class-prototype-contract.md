# C0 二職業のルール原型

この文書は 2026-10-24 の原型を整理した概要で、現在の七戦遠征の仕様ではありません。`npm run game:classes` で、魔法使いの元素の組み合わせと騎士の重刃を、一戦ずつ試せます。旧森林の `EmberRun` / `EmberSave` と保存を分けます。

盤面は 6×4。魔法使いは火・水・風を限られた数だけ無料で取得し、火と微光から焰爆、水と風から潮汐を作ります。騎士は初期の12金貨で限られた武装を選び、長剣と徽記から2×3の重刃を作ります。素材は戦前の合成時に消費し、戦中の自動施法に MP や元素の追加消費はありません。固定の取得元と敵を使い、保存された種子でランダムな遠征を生成する仕様ではありません。

当時の原型は魔法使い8道具、騎士4道具、3配方、各職業3つの取得元です。配置、回転、合成の失敗で資源を失わないこと、イベントの出所、一時停止・倍速、独立した戦前チェックポイント、壊れた保存の保護を検証します。旧データを黙って新しい職業に変換しません。

主な実装は [class_catalog.gd](../scripts/classes/class_catalog.gd)、[class_run.gd](../scripts/classes/class_run.gd)、[class_battle.gd](../scripts/classes/class_battle.gd)、[class_save.gd](../scripts/classes/class_save.gd)、[class_lab.gd](../scripts/classes/class_lab.gd) です。[当時の実装と検証](devlog/2026-10-24-class-rules.ja.md) · [現在の要件](requirements.md)
