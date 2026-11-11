# Godot MCP

このプロジェクトでは Godot-MCP 0.31.0、ローカルの GameDev-MCP-Server 9.2.13、.NET SDK 8.0.426 を使用しています。

## 起動

プロジェクトのルートで実行します。

```powershell
npm run godot:open
```

このコマンドはプロジェクト内の SDK で C# をビルドし、Godot .NET エディターを開いて、ローカル MCP サーバーを起動します。

同じプロジェクトのエディターを直接開いている場合は、先に作業を保存して閉じてから実行してください。Godot を直接起動すると、このスクリプトが設定するローカル SDK、NuGet キャッシュ、`GODOT_MCP_*` の環境変数は引き継がれません。2026-11-02 の確認では、直接開いたエディターは Cloud モードで、Codex はローカルサーバーに接続しようとしており、接続が拒否されました。

`npm run godot:status` でエディターとサーバーの状態を確認できます。クライアントの設定変更後は、ツールを読み込み直すために新しい Codex セッションが必要になる場合があります。CLI の準備ができても、現在のセッションに MCP ツールが自動的に追加されるとは限りません。

2026-11-02 にエディターを保存・終了し、このコマンドで再起動したところ、`godot:status` は Connected を返しました。Codex のローカル MCP アドレスに対する initialize、tools-list、rql-query、screenshot-viewport も成功しました。一方、そのセッションには Godot ツールが自動的には現れなかったため、確認には別のローカル MCP クライアントを使っています。Codex に自動接続されたことを確認したわけではありません。スクリーンショットはエディターのビューポートであり、ゲームの実行画面ではありません。

ビルド時にはプラグインが古い Dock API を呼ぶ非推奨の警告が3件ありました。エディターのログには `System.Net.Sockets.resources` の探索に関する表示も残っており、接続に成功したことは、この表示がなくなったことを意味しません。

```powershell
npm run godot:build
npm run godot:status
npm run godot:cli -- --help
```

## ファイルの場所

- Godot .NET エディター：ターミナルの `GODOT_BIN` で指定するか、プロジェクト内の `.tools/godot-editor-path.txt` にパスを記載。
- .NET SDK：`.tools/dotnet/`。
- NuGet の依存パッケージとキャッシュ：`.tools/nuget/`。
- エディタープラグイン：`addons/godot_mcp/`。
- MCP サーバー：`.godot/mcp-server/`。
- エディターのログ：`.tools/logs/editor.log`。
- Codex の MCP 設定：`.codex/config.toml`。このプロジェクトはローカルの Codex で信頼済みプロジェクトとして登録しています。

起動スクリプトは、まずターミナルの `GODOT_BIN` を使い、設定がない場合に Git 管理外のパスファイルを読みます。エディター付属の NuGet パッケージは `.tools/godot-nupkgs/` にコピーし、`NuGet.Config` から参照します。

MCP サーバーはローカルのループバックアドレスでのみ待ち受けます。ポートとプロジェクトのルートはプロジェクトパスから決まるため、パスを変更した場合は MCP 設定を生成し直し、Codex セッションを開き直してください。

SDK の環境変数は起動コマンドから子プロセスに渡されます。エディターのビルドでプロジェクト内の SDK を使うには `npm run godot:open` で起動してください。
