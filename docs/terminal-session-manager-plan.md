# Claude/Codex 横断セッションマネージャー実装計画

## Summary
`TerminalSession` 既存基盤（モデル・サービス・ViewModel・UI部品）を拡張し、`codex.app` 風のセッション管理体験を実現する。  
本計画では、従来の下部 Terminal パネル運用を廃止し、以下へ一本化する。

- セッション一覧専用ウィンドウ（常に1つ）
- セッション別実行ウィンドウ（セッションごとに1つ）
- Claude/Codex 横断検索（タイトル + メタ情報 + 本文ログ）

## 仕様確定
- 実装範囲: 全機能一括
- ウィンドウ構成: 一覧ウィンドウ1 + セッション別ウィンドウ
- 検索対象: タイトル + メタ情報 + 本文ログ
- インジケーター: 実行中セッション数（例: 実行中 17）
- 永続化: 再起動後にセッション情報を復元
- タイトル変更: 右クリックメニュー経由
- 導線: Terminal メニュー + ショートカット
- ログ保持: 1セッションあたり直近 2,000 行（リングバッファ）
- 既存下部パネル: 廃止（マネージャーへ一本化）
- ピン留め: 一覧上部固定（手動並べ替えなし）
- 表示順: ピン → 実行中 → 最終アクティビティ降順
- 検索結果表示: セッション + ヒット行プレビュー

## Public API / 型 / I/F 変更

### 1. Models
対象: `starfiler-app/starfiler/Models/TerminalSession.swift`

- `TerminalSessionStatus` に復元時停止状態を追加（例: `stopped`）
- `TerminalSession` に以下を追加
  - `isPinned`
  - `lastOpenedAt`
  - `updatedAt`

### 2. Service
対象: `starfiler-app/starfiler/Services/TerminalSessionService.swift`

- `TerminalSessionProviding` 拡張
  - `pin/unpin`
  - `rename`
  - `appendOutput`
  - `search`
  - `loadPersistedSessions`
  - `persistNow`
- サービスをセッション真実源（SoT）として統一
- ログリング（2,000行）を内包し、検索を提供

### 3. Config
対象: `starfiler-app/starfiler/Config/ConfigManager.swift`

- `TerminalSessions.json` の load/save API 追加

新規: `starfiler-app/starfiler/Config/TerminalSessionsConfig.swift`

- 永続化 DTO
  - セッション配列
  - ログ行
  - フォーマットバージョン
  - 保存時刻

### 4. ViewModel
新規: `starfiler-app/starfiler/ViewModels/TerminalSessionManagerViewModel.swift`

- 管理対象
  - 検索クエリ
  - フィルタ（All / Claude / Codex）
  - 並び替え
  - ヒットスニペット

### 5. Window / View
新規: `starfiler-app/starfiler/Windows/TerminalSessionManagerWindowController.swift`

- セッション一覧ウィンドウの単一インスタンス管理

新規: `starfiler-app/starfiler/Views/Terminal/TerminalSessionManagerViewController.swift`

- `NSSearchField + NSTableView` 一覧UI
- ヘッダー実行中件数表示
- 右クリックメニュー

新規: `starfiler-app/starfiler/Views/Terminal/LoggingLocalProcessTerminalView.swift`

- `LocalProcessTerminalView` を継承
- `dataReceived` フックでログ抽出・正規化

## 実装ステップ
1. データ基盤拡張
   - create/remove/rename/pin/status/output/search を `TerminalSessionService` に集約
   - ANSI除去 + 行単位ログ化 + リングバッファ化
2. 永続化追加
   - `TerminalSessions.json` 保存/復元
   - 復元時に `running/launching` を `stopped` へ正規化
3. 一覧ウィンドウ新設
   - 実行中件数ヘッダー
   - provider/status/title/cwd/snippet/pin 表示
4. セッション別ウィンドウ運用
   - `TerminalSessionWindowController` を本接続
   - 同一セッションは既存ウィンドウ再利用
5. 下部パネル撤去
   - `MainContainerViewController` / `MainWindowController` のパネル依存削除
   - `toggleTerminalPanel` は Session Manager 表示トグルへ再マップ
6. 検索 + 右クリック操作仕上げ
   - 100-150ms デバウンス
   - `Rename Session…` `Pin/Unpin` `Open Session` `Close Session`
7. メニュー導線統合
   - `Terminal > Session Manager` 追加（ショートカット付与）
   - `Launch Claude Code` / `Launch Codex CLI` は継続

## テスト計画

### Unit: TerminalSessionService
- 作成/削除/rename/pin 反映
- 並び順（ピン→実行中→新しい順）
- ログ2,000行ローテーション
- title/cwd/provider/log 横断検索
- 復元時状態正規化（running→stopped）

### Unit: TerminalSessionManagerViewModel
- クエリ無し一覧
- クエリ有りスコア順 + snippet + provider フィルタ

### UI Test
- Session Manager 単一インスタンス表示
- Claude/Codex 起動でセッション別ウィンドウ生成
- 実行中件数インジケーター更新
- 右クリック rename の反映
- ピン留めの上部固定
- 本文ログ横断検索ヒット

### Regression
- `launchClaude` `launchCodex` 既存キーバインド動作維持
- 既存設定環境での起動互換

## 前提・デフォルト
- Session Manager ウィンドウは常に1つ
- 本文検索対象は直近2,000行
- ヒット行への厳密スクロール同期は初版対象外
- ピンの手動並べ替えは対象外
- `terminalPanelVisible` は互換読み込みのみ（UI利用しない）

## 備考
このドキュメントは実装前提の合意仕様であり、この時点ではコード変更を含まない。
