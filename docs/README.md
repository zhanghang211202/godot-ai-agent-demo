# 複数職業と道具の組み合わせ RPG：文書一覧（タイトル未定）

**現在は魔法使いを優先し、騎士と C2 は後回しにしています。** `npm run game:mage` は七戦の魔法使い遠征、`npm run game:mage:trial` は以前の一戦版を起動します。[魔法使いの当初の計画](mage-first-plan.md) · [一戦版の実装](iteration-mage-trial.md) · [七戦版の記録](devlog/2026-11-10-mage-seven-battles.ja.md)

以前の[魔法使いの拡張](iteration-mage-expansion.md)では、受撃時の法盾、鏡翼の蛾、茨の石像と四種類の魔法を追加し、三体から敵を選べる一戦と六つの元素配方を作りました。[開発記録](devlog/2026-10-27-mage-expansion.ja.md)

[魔法エフェクトの第二版](iteration-mage-vfx.md)では、溜め、曲線の飛行、段階を分けた命中、残光、小さなピクセル模様を追加しました。戦闘結果は変更せず、関連する1350項目の確認が通っています。[開発記録](devlog/2026-10-27-mage-vfx.ja.md)

2026-10-27 に `npm run game:classes` へ[戦闘フィードバックの試作](iteration-c1-feedback.md)を追加しました。命中・多段・装甲の数字、受撃時の点滅と揺れ、勝敗のフェード、キャラクター画像の透明部分の処理を含みます。元画像のピクセル密度の統一と、専用の受撃・退場姿勢は未完成です。

`npm run game` は v0.3 の森林美術試作（M1-A/B）です。`npm run game:classes` は[C0 ルール](iteration-c0-rules.md)と[C1 の四姿勢の動き](iteration-c1-motion.md)を試せます。MA の施法、KA の長剣と重刃、二つの背景と一戦があり、動きは実際のイベント、一時停止、再生速度と連動します。当時は専用の受撃・退場姿勢、敵・道具、六流派が未完成でした。森林版とその保存データは引き続き使えます。

2026-10-23 の方針では、バッグを中心にしつつ、職業ごとに戦い方・資源の集め方・背景を変え、各キャラクターに少なくとも三つの流派を設けます。初期候補は魔法使いと H 方向の近接騎士、錬金術師は将来の候補です。[職業と流派の設計](classes-and-builds.md)は初期の六案を説明しています。C0 で実装したのは二案の最初の試作で、それ以外は計画です。キャラクターの美術目標は細かな 16-bit fantasy / tactical RPG です。[八つの設定案](art-style-exploration.md)と[オフライン比較ページ](concepts/2026-10-23/index.html)は初期の探索資料です。

## 現在の開発基準と実装記録

| 文書 | 内容 |
| --- | --- |
| [魔法使い優先の計画](mage-first-plan.md) | 当初の範囲、制作順、後回しにする内容 |
| [法盾とコンテンツの拡張](iteration-mage-expansion.md) | 受撃時の法盾、二種類の敵、四種類の魔法、保存と実機比較 |
| [魔法使い一戦版](iteration-mage-trial.md) | 専用の起動方法、敵・道具・効果、配置、プレビューと検証 |
| [魔法エフェクト第二版](iteration-mage-vfx.md) | 三つの魔法と敵の攻撃の四段階、タイミング、重ね順と GPU の確認 |
| [C1 戦闘フィードバック](iteration-c1-feedback.md) | 受撃、フェード、数字、透明度、勝敗の自動操作と元画像の制限 |
| [C1 四姿勢の動き](iteration-c1-motion.md) | 三組の動き、イベントのタイミング、一時停止、速度、実機 GIF と元画像の制限 |
| [C1 静止画の組み込み](iteration-c1-static-art.md) | 三姿勢、二背景、武器、実機画像、検査と残る問題 |
| [初期キャラクターの外観基準](character-baselines.md) | 選択済みの MA 月庭礼装と KA 旗の長槍、武器と専用素材の課題 |
| [二職業・六案の比較](character-design-review.md) | 全身、細部、縮小表示、オフラインページと Godot 上の確認 |
| [製品要件](requirements.md) | 目標、現状との差、必要な内容、機能・非機能要件、受け入れ条件と対象外 |
| [C0 の実装](iteration-c0-rules.md) | ルール実験の起動、操作、検査、実機での自動操作と制限 |
| [C0 ルールの契約](class-prototype-contract.md) | 資源、道具、配方、時間、イベントと独立した保存 |
| [職業と流派の設計](classes-and-builds.md) | 魔法使いと騎士の各三案、資源、空間、戦闘と互換性 |
| [開発計画](development-plan.md) | マイルストーン、作業、依存関係、検証、リスクと次の作業 |
| [美術仕様](art-direction.md) | 現状の画面、ピクセルの大きさ、配色、素材、動きと受け入れ条件 |
| [美術と設定の探索](art-style-exploration.md) | 八つの仮名、主人公、背景、道具とコンセプト画像 |
| [複数職業の美術計画](art-retheme-plan.md) | 二職業の比較、背景、準備画面、実機確認 |
| [参考資料の調査](reference-research.md) | Wiki、公式資料、YouTube の三動画から確認した情報とその範囲 |
| [素材の出典](asset-credits.md) | 使用素材の制作方法、出典とライセンス |

従来の計画順は **C0 職業ルールと接続 → C1 二職業各一流派の一戦 → C2 各三流派・五戦 → C3 説明、バランス、Windows 向け完成** でした。C1 は初期 Demo 全体の完成を意味せず、旧単一主人公版の素材数を新しい職業の総量には使いません。その後、騎士と C2 は後回しになりました。

## 開発過程とブログ用の資料

- [開発ログと各版のスクリーンショット](devlog/README.ja.md)
- [魔法使い一人へ絞った一戦](devlog/2026-10-27-mage-trial.ja.md)
- [実際の命中を読める画面へ](devlog/2026-10-27-c1-feedback.ja.md)
- [施法・長剣・重刃の四コマを実戦へ](devlog/2026-10-26-c1-motion.ja.md)
- [二職業の静止画の組み込みと修正](devlog/2026-10-26-c1-static-art.ja.md)
- [A＋A の外観の選択と反映](devlog/2026-10-25-character-selection.ja.md)
- [六つのキャラクター案と Godot 上の比較](devlog/2026-10-24-character-studies.ja.md)
- [C0 二職業の試作](devlog/2026-10-24-class-rules.ja.md)
- [二職業の要件整理](devlog/2026-10-23-dual-class-planning.ja.md)
- [細かなピクセルアートの設定探索](devlog/2026-10-23-art-exploration.ja.md)
- [森林美術試作の記録](devlog/2026-10-22-art-sample.ja.md)
- [要件整理の記録](devlog/2026-10-21-planning.ja.md)
- [ブログ草稿](blog/emberpack-making-of.ja.md)

スクリーンショットのフォルダーには各版の実機画面を残します。将来のコンセプト画像や素材案は別に明記し、過去の画像を上書きせず、実装済みの証拠としても扱いません。

## 旧版の資料

- [v0.1 最初の Demo 計画](demo-plan.md)：初期の範囲と簡略化。当時のルールには後に変更されたものもあります。
- [v0.2 の範囲と確認](iteration-02.md)：12装備、方向支援、祝福、保存の記録。
- [起動と操作](../README.md)
- [ローカル MCP の設定](../MCP_SETUP.md)
