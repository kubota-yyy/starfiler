# Starfiler - Mac専用デュアルペインファイラー 実装プラン

## Context

macOS専用のキーボード駆動型デュアルペインファイラーを新規開発する。「あふ」の高速キーボード操作と「yazi」のモダンなUXを参考に、macOSネイティブの品質を持つパワーユーザー向けツールを目指す。リポジトリはモノレポ構成で、macOSアプリのコードは `starfiler-app/` ディレクトリに配置する。

### 確定要件

| 項目 | 決定 |
|------|------|
| 配布方法 | 未定（サンドボックス前提設計） |
| 対象OS | macOS 15 (Sequoia)+ |
| キー操作 | Vim風 (hjkl) デフォルト、JSON設定でカスタマイズ可 |
| ペイン表示 | フラットリスト（あふ風）NSTableView |
| カラム | ファイル名・サイズ・更新日時の3列 |
| お気に入り | 手動グループ管理（プロジェクト単位） |
| 操作安全性 | あふ風（確認ダイアログ最小、高速重視） |
| プレビュー | 3ペイン目（右端）Quick Look、トグル表示 |
| 検索 | インクリメンタルフィルタ + Spotlight検索 |
| 設定形式 | JSON |
| アンドゥ | あり（NSUndoManager連携） |
| D&D | あり（ペイン間 + Finder連携） |
| タブ | MVPでは不要 |
| 外部連携 | MVPでは不要 |

---

## アーキテクチャ: MVVM + Service Layer

ViewModelはAppKitに依存せず、純粋なSwiftで実装しテスト可能にする。ServiceレイヤーでOS操作をカプセル化し、プロトコル経由で注入する。

```
Views (AppKit)  →  ViewModels (@Observable)  →  Services (protocols)  →  Models (structs)
```

- **@Observable** (Swift 5.9+) でViewModel→View通知
- **Swift Concurrency** (async/await, actor) で非同期処理
- **NSUndoManager** でファイル操作のアンドゥ

---

## プロジェクト構造

```
starfiler/                          # モノレポルート
├── starfiler-app/                  # macOSアプリ本体
│   ├── starfiler.xcodeproj
│   ├── starfiler/
│   │   ├── App/
│   │   │   ├── AppDelegate.swift              # アプリライフサイクル、メインメニュー
│   │   │   └── Info.plist
│   │   ├── Windows/
│   │   │   └── MainWindowController.swift     # ウィンドウ管理
│   │   ├── Views/
│   │   │   ├── SplitView/
│   │   │   │   └── MainSplitViewController.swift  # NSSplitViewController（3ペイン管理）
│   │   │   ├── Pane/
│   │   │   │   ├── FilePaneViewController.swift   # ファイルリストペイン（NSTableView）
│   │   │   │   ├── FileTableView.swift            # カスタムNSTableView（キー入力インターセプト）
│   │   │   │   ├── FileTableCellView.swift        # セルビュー
│   │   │   │   └── FileTableDataSource.swift      # DataSource/Delegate
│   │   │   ├── Preview/
│   │   │   │   └── PreviewPaneViewController.swift # Quick Lookプレビュー
│   │   │   ├── StatusBar/
│   │   │   │   └── StatusBarView.swift            # パス・選択数・フィルタ表示
│   │   │   └── FilterBar/
│   │   │       └── FilterBarViewController.swift  # インクリメンタルフィルタ入力
│   │   ├── ViewModels/
│   │   │   ├── FilePaneViewModel.swift        # 1ペインの全ロジック（最重要ファイル）
│   │   │   ├── PreviewViewModel.swift         # プレビュー状態管理
│   │   │   └── MainViewModel.swift            # 両ペイン統合、クリップボード、操作キュー
│   │   ├── Models/
│   │   │   ├── FileItem.swift                 # ファイル/ディレクトリ情報モデル
│   │   │   ├── DirectoryContents.swift        # ソート・フィルタ済みディレクトリ状態
│   │   │   ├── PaneState.swift                # カーソル位置、マーク、履歴
│   │   │   ├── NavigationHistory.swift        # 戻る/進むスタック
│   │   │   ├── BookmarkGroup.swift            # お気に入りグループ
│   │   │   └── FileOperation.swift            # 操作タイプ + アンドゥデータ
│   │   ├── Services/
│   │   │   ├── FileSystemService.swift        # ディレクトリ読み込み（FileManager）
│   │   │   ├── FileOperationService.swift     # コピー/移動/削除/リネーム実行
│   │   │   ├── FileOperationQueue.swift       # actor: 非同期操作キュー + 進捗 + アンドゥ履歴
│   │   │   ├── DirectoryMonitor.swift         # DispatchSource: ディレクトリ変更監視
│   │   │   ├── SpotlightSearchService.swift   # NSMetadataQuery: Spotlight検索
│   │   │   ├── SecurityScopedBookmarkService.swift # サンドボックス: ブックマーク管理
│   │   │   └── TrashService.swift             # NSWorkspace.recycle ラッパー
│   │   ├── Keyboard/
│   │   │   ├── KeybindingManager.swift        # JSON設定読み込み、キー→アクション変換
│   │   │   ├── KeyEvent.swift                 # キー + 修飾キーモデル
│   │   │   ├── KeyAction.swift                # バインド可能な全アクションenum
│   │   │   ├── KeyInterpreter.swift           # マルチキーシーケンス解釈（gg, dd等）
│   │   │   └── VimModeState.swift             # normal/visual/filterモード管理
│   │   ├── Config/
│   │   │   ├── ConfigManager.swift            # 設定ファイルの読み書き
│   │   │   ├── AppConfig.swift                # アプリ設定モデル（Codable）
│   │   │   ├── KeybindingsConfig.swift        # キーバインド設定モデル
│   │   │   └── BookmarksConfig.swift          # お気に入り設定モデル
│   │   ├── DragDrop/
│   │   │   ├── FileDragSource.swift           # ドラッグ元
│   │   │   └── FileDropTarget.swift           # ドロップ先
│   │   ├── Extensions/
│   │   │   ├── URL+Extensions.swift
│   │   │   ├── NSTableView+Extensions.swift
│   │   │   ├── FileManager+Extensions.swift
│   │   │   └── NSEvent+Extensions.swift
│   │   ├── Resources/
│   │   │   ├── Assets.xcassets
│   │   │   ├── DefaultKeybindings.json        # デフォルトVimキーバインド
│   │   │   └── DefaultConfig.json
│   │   └── starfiler.entitlements             # サンドボックス権限
│   └── starfilerTests/
│       ├── Models/
│       ├── ViewModels/
│       ├── Services/
│       ├── Keyboard/
│       └── Config/
└── docs/
```

---

## 主要モジュール設計

### キーバインドシステム

4層構造: `NSEvent → KeyInterpreter → KeybindingManager → KeyAction`

- **KeyInterpreter**: Vimのマルチキーシーケンス（`gg`, `dd`）をステートフルに解釈。500msタイムアウト
- **KeyAction**: 全バインド可能アクション列挙型（cursorUp, copy, paste, togglePreview等 約30種）
- **モード**: normal / visual / filter の3モード

デフォルトキーバインド（JSON設定でカスタマイズ可能）:
```json
{
  "normal": {
    "j": "cursorDown", "k": "cursorUp", "h": "cursorLeft", "l": "cursorRight",
    "g g": "goToTop", "G": "goToBottom",
    "Space": "toggleMark", "v": "enterVisualMode",
    "y": "copy", "p": "paste", "d d": "delete", "c w": "rename",
    "/": "enterFilterMode", "Tab": "switchPane",
    "Ctrl-p": "togglePreview", ".": "toggleHiddenFiles",
    "u": "undo", "b": "openBookmarks", "B": "addBookmark"
  }
}
```

### 選択/マークモデル（あふ準拠）

- **カーソル**: 常に1つ（j/kで移動）
- **マーク**: Space で個別トグル。複数マーク可能。視覚的に区別表示
- **ビジュアルモード**: v で開始、カーソル移動で範囲マーク
- **操作対象**: マークがあればマーク済みファイル、なければカーソル位置のファイル

### ファイル操作パイプライン

```
KeyAction → MainViewModel → FileOperationQueue (actor) → FileOperationService → FileManager
                                    ↓
                              FileOperationRecord → NSUndoManager（逆操作を登録）
```

| 操作 | アンドゥ |
|------|----------|
| コピー | コピー先をゴミ箱へ |
| 移動 | 元の場所に移動 |
| ゴミ箱 | ゴミ箱から復元（NSWorkspace.recycle のURL使用） |
| リネーム | 元の名前にリネーム |
| ディレクトリ作成 | 作成したディレクトリをゴミ箱へ |

### サンドボックス戦略

- **Entitlements**: `app-sandbox` + `files.user-selected.read-write` + `files.bookmarks.app-scope`
- **SecurityScopedBookmarkService**: 参照カウント付きアクセス管理
  - `startAccessing()` / `stopAccessing()` をペインナビゲーション時に呼び出し
  - ブックマークデータはアプリコンテナ内にJSON保存
  - Staleブックマーク検出時は自動再作成 or ユーザー再承認
- **初回起動**: NSOpenPanelでホームディレクトリへのアクセスを要求

### ディレクトリ監視

- `DispatchSource.makeFileSystemObjectSource` を各ペインに1つ
- ナビゲーション時にstop→start切り替え
- 200msデバウンスでUI更新

---

## 実装フェーズ（順序）

### Phase 1: スケルトン + シングルペイン
Xcodeプロジェクト作成、AppDelegate、MainWindowController、FileItem、FileSystemService、FilePaneViewModel、NSTableView付きFilePaneViewController、矢印キーナビゲーション、ステータスバー

### Phase 2: デュアルペイン + SplitView
NSSplitViewController（左右2ペイン）、MainViewModel、Tab切り替え、アクティブペイン表示

### Phase 3: キーバインドシステム
KeyEvent/KeyAction/KeyInterpreter/KeybindingManager、Vim風デフォルト、マルチキーシーケンス、JSON設定読み込み

### Phase 4: ファイル操作 + アンドゥ
FileOperationService/Queue、コピー/移動/削除/リネーム/mkdir、NSUndoManager連携、進捗表示

### Phase 5: マーク/選択システム
Space マーク、ビジュアルモード、マーク対象のファイル操作

### Phase 6: ソート/フィルタ/隠しファイル
カラムヘッダクリックソート、インクリメンタルフィルタUI、隠しファイルトグル

### Phase 7: プレビューペイン
3番目のNSSplitViewItem、QLPreviewView、トグル表示、アクティブペインの選択に追従

### Phase 8: サンドボックス + Security-Scoped Bookmarks
SecurityScopedBookmarkService、参照カウント管理、初回起動フロー、staleブックマーク処理

### Phase 9: お気に入り/ブックマーク
BookmarksConfig、手動グループ管理UI、クイックジャンプ、サンドボックスブックマーク連携

### Phase 10: ディレクトリ監視
DirectoryMonitor (DispatchSource)、デバウンス、カーソル/マーク位置保持での更新

### Phase 11: ドラッグ&ドロップ
NSDraggingSource/Destination、ペイン間D&D、Finder連携、Option+ドロップで移動

### Phase 12: Spotlight検索
SpotlightSearchService (NSMetadataQuery)、検索UI、結果ナビゲーション

### Phase 13: ポリッシュ + 状態復元
前回ディレクトリ復元、ウィンドウフレーム保存、メニューバー、パフォーマンス最適化（大量ファイル対応）、ダークモード、アクセシビリティ

---

## 検証方法

1. **ユニットテスト**: Models, ViewModels, Services, Keyboard のテスト（AppKit非依存でテスト可能な設計）
2. **手動テスト**: 各Phase完了時に以下を確認
   - ディレクトリナビゲーション（10,000+ファイルのディレクトリで速度確認）
   - 全キーバインドの動作確認
   - ファイル操作（コピー/移動/削除/リネーム） + アンドゥ
   - サンドボックス環境での権限テスト
   - プレビュー（画像, テキスト, PDF, 動画）
3. **ビルド**: `cd starfiler-app && xcodebuild -scheme starfiler -configuration Debug build`
4. **テスト実行**: `cd starfiler-app && xcodebuild test -scheme starfiler`
