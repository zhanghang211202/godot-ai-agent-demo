# 2026-11-02：ローカル Godot MCP の接続を検証

直接開いたエディターは Cloud モード、Codex はローカルを向いており、ポートへの接続が拒否されていました。ユーザーが保存して閉じた後、`npm run godot:open` からプロジェクト内 .NET SDK でビルドし、同じ Godot .NET エディターをローカル MCP の環境変数付きで開き直しました。ユーザーのウィンドウをこちらから強制終了していません。

Windows の Godot 4.7.2 .NET、Godot-MCP 0.31.0、GameDev-MCP-Server 9.2.13 で以下を確認しました。

- ビルド成功、エラー0、旧 Dock API の `CS0618` 警告3件。
- `npm run godot:status` はエディター実行中・サーバー Connected。
- 実際の設定済み loopback MCP エンドポイントに独立クライアントから initialize / tools/list / tools/call を送信。プロトコル `2025-03-26`、15ツールを確認。
- `rql-query` の読み取り結果は開いている `Emberpack` の `Control` ルートと `res://scripts/gameplay/main.gd`。`screenshot-viewport` は2Dエディターの [PNG](screenshots/2026-11-02-mcp-v1/editor-viewport.png) を返却しましたが、今回のビューは灰色の空画面です。ゲーム実行画面ではありません。
- ツール一覧に `rql-mutate` はありますが、書き込み、AnimationPlayer のトラック編集、ゲーム実行中のエラー取得はテストしていません。Animation Tools 拡張のパッケージ参照もありません。

エディターログには接続成功前の再接続警告と `System.Net.Sockets.resources` の依存解決探測メッセージが残りました。接続確認のみで、その警告を修正済みとは扱いません。現在の Codex セッションには Godot ツールが自動追加されていないため、実際の MCP プロトコル検証は別のローカルクライアントで行いました。セッションを開き直した後の自動登録は未確認です。

作業中に `scenes/main.tscn` にエディター保存による UID 等の差分があることを確認しました。ユーザーが保存した変更の可能性があるため、元に戻したりこの記録と一緒にコミットしたりしていません。アニメーション PoC は未実施です。
