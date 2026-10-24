# 格子合成 RPG 開発記録（新タイトルは選定中）

ブログ用の素材を、実際のコード・実行結果・スクリーンショットと一緒に残すための記録です。
記録日は日本時間（JST）を基準にします。作業時間は計測していないため、所要時間や生産性の数値は記載しません。

## 記録

- [2026-10-21：環境構築から Demo 0.2 まで](2026-10-21.ja.md)
- [2026-10-21：要件・開発計画とアート改善の整理](2026-10-21-planning.ja.md)
- [2026-10-22：実機アートサンプルと可変レイアウト](2026-10-22-art-sample.ja.md)
- [2026-10-23：精細なピクセルキャラクターと八つの世界観](2026-10-23-art-exploration.ja.md)
- [2026-10-23：バックパックを核にした二職業・六構築の要件](2026-10-23-dual-class-planning.ja.md)
- [2026-10-24：二職業の資源・編織・一戦が動くC0原型](2026-10-24-class-rules.ja.md)
- [日本語ブログ草稿](../blog/emberpack-making-of.ja.md)
- [現在のドキュメント一覧](../README.md)
- [最初の実装計画](../demo-plan.md)
- [0.2 の実装範囲と検証](../iteration-02.md)
- [参考ゲームの調査記録](../reference-research.md)
- [素材とライセンス](../asset-credits.md)

## スクリーンショット

| 版 | 内容 | 画像 |
| --- | --- | --- |
| 0.1 | 最初の準備画面 | [prepare.png](screenshots/v0.1/prepare.png) |
| 0.1 | 自動戦闘 | [battle.png](screenshots/v0.1/battle.png) |
| 0.2 | 方向付きの支援マス | [prepare.png](screenshots/v0.2/prepare.png) |
| 0.2 | 自動戦闘と装備のクールダウン | [battle.png](screenshots/v0.2/battle.png) |
| 0.2 | 初期資源だけで作れる合成例 | [forging.png](screenshots/v0.2/forging.png) |
| 0.2 | 勝利後の祝福選択 | [blessings.png](screenshots/v0.2/blessings.png) |
| 0.2 | 一時停止とセーブのメニュー | [menu.png](screenshots/v0.2/menu.png) |
| 0.3 sample | 主役・苔団と皮革バッグ / 紙の手記 | [prepare.png](screenshots/v0.3-sample/prepare.png) |
| 0.3 sample | 実行中の戦闘、5秒 / 無音 / 縮小GIF | [battle-motion.gif](screenshots/v0.3-sample/battle-motion.gif) |
| 0.3 sample | ドラッグの占有範囲プレビュー | [drag-preview.png](screenshots/v0.3-sample/drag-preview.png) |
| 0.3 sample | 初期資源だけの合成例、旧素材を含む | [forging.png](screenshots/v0.3-sample/forging.png) |
| 0.3 sample | 祝福カードと全画面マスク | [blessings.png](screenshots/v0.3-sample/blessings.png) |
| 0.3 sample | 1280×800 / 1920×1080 | [小ウィンドウ](screenshots/v0.3-sample/prepare-1280x800.png) / [大ウィンドウ](screenshots/v0.3-sample/prepare-1920x1080.png) |
| C0 rules v1 | 法師：有限元素の取得と二つの法術。規則fixture、完成美術ではない | [構築](screenshots/c0-class-rules-v1/mage-built.png) / [結果](screenshots/c0-class-rules-v1/mage-result.png) |
| C0 rules v1 | 騎士：有限購入で重刃を鍛造。規則fixture、完成美術ではない | [構築](screenshots/c0-class-rules-v1/knight-built.png) / [結果](screenshots/c0-class-rules-v1/knight-result.png) |
| C0 rules v1 | 実際の1280×800準備画面、長い列はスクロール | [小ウィンドウ](screenshots/c0-class-rules-v1/mage-prepare-1280x800.png) |

すべて Godot で実行したゲーム画面です。0.1 の画像は公開済みコミット `ac878e9` からバイト単位で取り出しました。
0.2 の合成例は、デバッグ用に資源を増やしたものではなく、初期アイテムと18ゴールドだけを通常の購入・合成APIで操作した状態です。
祝福画面は最初の戦闘を通常の装備で勝った後の状態を再現しています。

画像の幅・高さ・サイズ・SHA-256・出典は [manifest.json](screenshots/manifest.json) に記録しています。
バージョン別の画像は上書きせず、将来の変更は新しい版のフォルダーに追加します。

C0の9枚はネイティブGodotの実行画面ですが、人物と背景は規則のための図式です。[版別マニフェスト](screenshots/c0-class-rules-v1/manifest.json)と魔法使い・騎士の取得/結果JSONも保存しました。撮影fixtureは通常の取得・合成APIを使い、所持金や完成装備を直接注入せず、プレイヤー保存を無効化しています。新しいキャラクター美術の完成証拠とは区別します。

2026-10-23 の[八つのコンセプト画像](../art-style-exploration.md)は別の `docs/concepts/2026-10-23/` に保存しています。上の表とは異なり、Godot の実行画面ではありません。[比較ページ](../concepts/2026-10-23/index.html)はリポジトリーを取得後、ローカルブラウザーで開けます。

## 次の記録で残すもの

1. 今回の目標と、実装した範囲。
2. 実際に起きた問題、修正内容、確認方法。
3. 実行した検証コマンドと、成功・失敗・警告の区別。
4. 前後の画面、必要なら再現用の入力や初期状態。
5. コミット、未実装の要素、まだ確認していない環境。

## 撮影の再現

```powershell
npm run game -- -- --screenshot=D:/path/to/prepare.png --auto-quit
npm run game -- -- --screenshot=D:/path/to/forging.png --auto-quit --demo-forge
npm run game -- -- --screenshot=D:/path/to/blessings.png --auto-quit --demo-reward
npm run game -- -- --screenshot=D:/path/to/menu.png --auto-quit --demo-menu
```

出力先のディレクトリーは先に作成します。撮影モードは本来のプレイヤーセーブを読み書きしません。
`--demo-forge` や `--demo-reward` は撮影用に合法な操作を自動実行する再現用オプションです。
