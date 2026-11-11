# 美術素材とフォントの出典

## 魔法使いの敵と魔法の拡張・2026-10-27

`assets/art/mage-expansion-v1/` の鏡翼の蛾、茨の石像の四姿勢、四つの魔法アイコンは内蔵の imagegen で生成しました。元の PNG と alpha を保持し、[生成時の指示](../assets/art/mage-expansion-v1/prompts.json)と[寸法、使用範囲、alpha、ハッシュ](../assets/art/mage-expansion-v1/manifest.json)を保存しています。実行用に作った独立した画像であり、ユーザーの非公開の参考画像は入力・アップロードしていません。新しい法盾、光、風刃、蒸気、渦はプロジェクトのコードで描画し、以前に生成した素材は変更していません。

この Demo の人物、道具アイコン、森林は本プロジェクトのために制作しました。参考ゲーム『靠装勇者：背包合成 RPG』とその Wiki、動画は遊びと見せ方の調査に使用しています。そのゲームの元画像、スクリーンショットの切り抜き、アイコン、キャラクター画像、音声は使用していません。

| ファイル | 出典と制作方法 |
| --- | --- |
| `scripts/visuals/pixel_art.gd` | 本プロジェクト独自のコードによるピクセルアート。主人公、スライム、ゴブリン、狼、樹人、装備、金貨、体力のアイコンなどを、手書きのピクセル配列と色から Godot の `Image` で実行時に生成。参考ゲームの素材は読み込まない。 |
| `scripts/visuals/pixel_art_v03.gd`、`assets/art/v03/` | コードによる独自の美術試作。主人公と苔団の各14フレーム、剣・盾・砥石の小アイコンと盤面用画像。PNG は同じコードから書き出したもの。[一覧](../assets/art/v03/manifest.json)に素材と SHA-256 を記録。残りの装備と敵は旧素材を仮使用している。 |
| `scripts/ui/forest_stage.gd`、`assets/art/v03/environments/forest/stage.png` | コードで描いた独自の 512×144 森林。色数を限定し、独立した固定乱数を使い、実行時にキャッシュする。複数の層を一枚に合成しており、参考ゲームや外部の画像は使用していない。 |
| `scripts/ui/ember_theme.gd` | コードで描いた革、紙、銅の部品、ボタン。 |
| `assets/art/forest_background.png` | v0.1/v0.2 で使った独自の **imagegen** 森林背景。過去との比較用に残し、現在の森林試作は上記のコードによる背景を使う。生成指示は [art-direction.md](art-direction.md) の付録に記録。参考ゲームの画像やスクリーンショットではない。 |
| `assets/fonts/NotoSansCJKsc-Regular.otf` | **Noto Sans CJK SC Regular**。内蔵バージョンは **2.004**、著作権表示は **© 2014–2021 Adobe (http://www.adobe.com/)**。[Noto CJK 公式リポジトリのフォント](https://github.com/notofonts/noto-cjk/blob/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf)を使用。 |

Noto Sans CJK は **SIL Open Font License 1.1** を使用します。[同梱のライセンス全文](../assets/fonts/OFL.txt)と [Noto CJK 公式ライセンス](https://github.com/notofonts/noto-cjk/blob/main/Sans/LICENSE)を参照してください。フォントのライセンスと内蔵著作権表示は、プロジェクトと共に配布する際にも保持します。

## キャラクターの外観案・2026-10-24

`docs/concepts/2026-10-24-characters/` の六枚の PNG は、魔法使いと H 騎士の方向に沿って内蔵 **imagegen** で個別に生成しました。元の alpha を保った外観比較用の画像で、戦闘用の画像、アニメーション表、ゲーム画面ではありません。[生成指示](concepts/2026-10-24-characters/prompts.json)、[寸法と SHA-256](concepts/2026-10-24-characters/manifest.json)、[確認と制限](character-design-review.md)を保存しています。以前の A/H 案は方向の参考です。ユーザーの二枚の図鑑はピクセル表現の参考としてのみ使い、元画像とそのインポートファイルは公開していません。

## C1 静止キャラクターと背景・2026-10-26

`assets/art/c1-static-v1/` の戦闘用の立ち姿三枚と職業ごとの背景二枚は、内蔵 **imagegen** でそれぞれ生成しました。人物は本プロジェクトで選んだ MA／KA の独自コンセプトを外観の参考に、姿勢を新たに描いたものです。旧コンセプトの比較画像やユーザーの図鑑を切り取っていません。元 PNG の生成結果、[生成指示](../assets/art/c1-static-v1/prompts.json)、[元の寸法・alpha・SHA-256](../assets/art/c1-static-v1/manifest.json)を保持しています。ローカルの職業シーンに組み込んだ静止候補ですが、ピクセル格子、色、透明な縁の整理が必要で、連続した姿勢は含みません。手前の地面、接地する影、仮素材と明記した木製標的はコードで描いています。

## C1 四姿勢の動き・2026-10-26

`assets/art/c1-motion-v1/` の三枚の専用画像は、プロジェクトの MA／KA の外観と静止姿勢を参考に、内蔵 **imagegen** で生成・編集しました。四姿勢の動きのために描いた画像で、旧コンセプトの切り抜きではありません。PNG は生成された alpha を保持し、Godot では各姿勢の使用範囲、共通の倍率、足元の基準点を使います。[指示と保存範囲](../assets/art/c1-motion-v1/prompts.json)、[実際の寸法・alpha・SHA-256と制限](../assets/art/c1-motion-v1/manifest.json)を残しています。

魔法使いの初期の指示文は完全には残っていないため、一覧では保存済みの仕様の要約と、この段階で記録した編集指示を区別しています。ユーザーが手と杖の問題を示すために送った切り抜きは問題の特定にのみ使い、一時画像や非公開の参考画像は公開していません。実行 GIF は Godot の実フレームを16 FPS固定で録画し、整数倍率の最近傍縮小と GIF 変換を行ったものです。生成画像を並べただけの実行証拠ではありません。

## C1 戦闘フィードバック・2026-10-27

この試作は `c1-motion-v1` の元画像を引き続き使い、元ファイルを変更していません。`class_actor.gdshader` は実行時のみ alpha のしきい値、受撃色、フェードを適用します。標的、浮く文字、命中の輪と小さな揺れはプロジェクトのコードで作成。内蔵 imagegen による三回のピクセル整理の試みは採用せず、[試行記録と指示](concepts/2026-10-26-pixel-cleanup/README.ja.md)で実機画面・完成素材ではないことを明記しています。実際の画面／GIF と GPU のテクスチャ読み戻し結果は[一覧](devlog/screenshots/c1-feedback-v1/manifest.json)に分けて保存しています。

## 魔法使いの一戦・2026-10-27

後のエフェクト第二版では `mage_spell_art.gd` が四種類の五色のピクセルマスクと三種類の炎を定義し、`mage_effects.gd` が溜め、軌跡、命中、余韻を描きます。外部素材や imagegen による新規出力はありません。実行時の画像は最近傍の整数倍率で拡大してキャッシュします。Movie Maker の実フレームは切り抜きと GIF 変換のみを行い、変換設定は[証拠の一覧](devlog/screenshots/mage-vfx-v2/manifest.json)にあります。コード描画の画像を生成コンセプトとは呼びません。

`assets/art/mage-trial-v1/` の衛兵四姿勢と八つの道具の画像は、実行用に内蔵 **imagegen** で生成した二枚の専用画像です。旧コンセプトやユーザーの図鑑の切り抜きではありません。元 PNG、[生成指示](../assets/art/mage-trial-v1/prompts.json)、[寸法、alpha、使用範囲と SHA-256](../assets/art/mage-trial-v1/manifest.json)を保存しています。三つの魔法と衛兵の星の効果は `mage_effects.gd` で描いたもので、外部ゲームの素材や画像生成による動画ではありません。主人公、月庭、フォントは上記の素材を引き続き使い、当時は魔法使いを優先して騎士の新規作業を後回しにしました。

## 外部のエディターツール

`addons/godot_mcp/` は [IvanMurzak/Godot-MCP v0.31.0](https://github.com/IvanMurzak/Godot-MCP/tree/v0.31.0) に由来し、Apache-2.0 を使用します。[ライセンス全文](../addons/godot_mcp/LICENSE)を同梱しています。NuGet の依存パッケージはプロジェクトの参照から復元し、このリポジトリには含めていません。
