# Starfiler 実装プラン アーキテクチャレビュー

## CRITICAL（実装前に必ず対処）

### 1. サンドボックスをPhase 2-3に前倒し（現Phase 8）
Phase 1-7をサンドボックスなしで作ると、全てのファイルアクセスコードの大幅な書き直しが必要になる。SecurityScopedBookmarkServiceはナビゲーションとファイル操作の基盤であり、最初期に実装すべき。

### 2. NSUndoManager + async actor の統合設計が不足
`NSUndoManager.registerUndo` は同期的にクロージャを呼ぶが、FileOperationQueueはactorで非同期。`Task {}` でラップすると fire-and-forget になり、連続Undoでレース条件が発生する。

**対策**: NSUndoManagerはUI/メニュー統合用に使いつつ、FileOperationQueue actor内に独自のundo stackを持ち、操作をシリアライズする。

### 3. シンボリックリンク/エイリアス処理が未記載
macOSには3種のリンク（POSIX symlink, hard link, Finderエイリアス）がある。表示区別、ナビゲーション時のリンク先解決、壊れたリンクの処理、循環リンク防止が必須。

### 4. .appバンドル（パッケージ）処理が未記載
`.app`は`hasDirectoryPath = true`だが、ファイルとして扱うべき。`URLResourceValues.isPackageKey`で判定し、デフォルトでは中に入らない設計が必要（「パッケージの内容を表示」は明示的アクション）。

---

## IMPORTANT（実装時に対処）

### @Observable + AppKit ブリッジ
- `withObservationTracking` は1回きり発火、任意スレッドから。どのプロパティが変わったか不明
- NSTableViewは「カーソル移動」（selectRowIndexes）と「アイテム変更」（reloadData）を区別する必要あり
- **対策**: @Observableに加え、`didSet`での明示的コールバックを併用

### NSTableView キーハンドリング
- 組み込みの矢印キー移動、type-to-select、Return編集、Spaceチェックボックスが全てVimバインドと衝突
- `FileTableView.keyDown`で全キーを先にインターセプトし、`super.keyDown`は明示的に制御
- `allowsTypeSelect = false` を設定

### Security-Scoped Bookmark エッジケース
- **ネストしたスコープ**: `/Users/alice/Projects`と`/Users/alice/Projects/repo`の両方をブックマーク→両方アクティブに保つ
- **シンボリックリンク越境**: ブックマークスコープ外へのsymlinkは`resolvingSymlinksInPath()`で検出→新しいアクセス要求
- **ボリュームマウント/アンマウント**: `NSWorkspace.didMountNotification`でブックマーク有効性を監視
- **ネットワークドライブ**: Security-scoped bookmarkは不安定。`volumeIsLocalKey`で検出して警告

### ディレクトリ監視とファイル操作の競合
ファイルコピー中にDispatchSourceが発火→リロード嵐でカーソル/マーク消失。
**対策**: DirectoryMonitorにsuspend/resumeを実装、操作中は一時停止。

### ViewModelは @MainActor にすべき
Swift 6のSendable厳格チェックに備え、ViewModelは`@MainActor`で宣言。バックグラウンドactorからの結果は`await`で受け取る。

### 2段階ディレクトリロード（大量ファイル対応）
1. Phase A（高速）: `.nameKey`, `.isDirectoryKey`のみで即時表示
2. Phase B（バックグラウンド）: サイズ、日時、メタデータをバッチで非同期取得→段階的にテーブル更新

### ゴミ箱の動作差異
- 外部ボリューム（FAT32/exFAT）にはゴミ箱がない→永久削除になる
- ネットワークボリュームの動作はまちまち
- TrashServiceでボリュームタイプを検出し、永久削除時は警告表示

### iCloud Drive対応
- `.icloud`プレースホルダーファイルの検出
- `ubiquitousItemDownloadingStatusKey`でダウンロード状態表示
- オンデマンドダウンロード(`startDownloadingUbiquitousItem`)

### ディレクトリ監視の前倒し
Phase 10→Phase 5-6に。監視なしだとファイル操作（Phase 4）のテスト時にコピー結果が見えず手動リフレッシュ必要。

---

## SUGGESTION（品質向上）

- **エラーハンドリング戦略**: Phase 1から統一`StarfilerError` enumを定義
- **NSDiffableDataSourceSnapshot**: NSTableViewの更新をアニメーション付きに。FileItemにinode等の安定IDが必要
- **マルチキータイムアウト**: 500ms→300msに短縮（設定可能に）
- **VoiceOver検出**: `NSWorkspace.shared.isVoiceOverEnabled`でアクセシビリティモード切替
- **Cmd-キーは絶対にインターセプトしない**: Cmd-Q/W/C/V等はmacOS標準に委譲
- **Combineをブリッジ層に**: `.receive(on: RunLoop.main)`, `.debounce`, `.removeDuplicates`はAppKitとの橋渡しに有用
- **DispatchSourceをAsyncStreamにラップ**: structured concurrencyとの統合
- **Task管理**: ナビゲーション時に前のTaskを必ずcancel（孤児Task防止）
- **NSLocalizedString**: Phase 1から使用。日本語のみでも将来の多言語化に備える
- **NSFileCoordinator**: 他アプリとのファイル操作衝突防止
- **クラッシュリカバリ**: マルチファイルコピー中のクラッシュに備えたジャーナル
- **アイコンキャッシュ**: 拡張子ベースでキャッシュ（ファイル単位は重い）
- **キーエコー**: ステータスバーに現在のキーバッファ表示（デバッグ用）
- **ディレクトリサイズ**: デフォルトはアイテム数表示、再帰サイズ計算は明示的アクション
- **Finderタグ**: コピー/移動時のカラーラベル保持

---

## 推奨フェーズ順序（修正案）

1. スケルトン + シングルペイン
2. **サンドボックス + Security-Scoped Bookmarks** ← Phase 8から前倒し
3. デュアルペイン + SplitView
4. キーバインドシステム
5. ファイル操作 + アンドゥ + マーク/選択 ← Phase 4+5を統合
6. **ディレクトリ監視** ← Phase 10から前倒し
7. ソート/フィルタ/隠しファイル
8. プレビューペイン
9. お気に入り/ブックマーク
10. ドラッグ&ドロップ
11. Spotlight検索
12. ポリッシュ + 状態復元
