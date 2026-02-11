# Starfiler - macOS Dual-Pane File Manager

## プロジェクト概要
macOS 15+ 専用のキーボード駆動型デュアルペインファイラー。
「あふ」の高速キーボード操作と「yazi」のモダンUXを参考にしたネイティブアプリ。

## 技術スタック
- **言語**: Swift (macOS 15+ / Swift 5.9+)
- **UI**: AppKit (NSTableView, NSSplitView) + 部分的にSwiftUI
- **アーキテクチャ**: MVVM + Service Layer
- **非同期**: Swift Concurrency (async/await, actor)
- **設定**: JSON (Codable)
- **サンドボックス**: Security-Scoped Bookmarks

## ディレクトリ構成
```
starfiler/              # モノレポルート
├── starfiler-app/      # macOSアプリ (Xcodeプロジェクト)
├── docs/               # 設計ドキュメント
└── .claude/            # Claude Code設定・スキル
```

## 設計原則
- **ViewModelはAppKit非依存**: `import AppKit` 禁止。純粋Swiftでテスト可能に
- **ViewModelは @MainActor**: Swift 6 Sendable準拠
- **Serviceはプロトコル経由で注入**: テスタビリティ確保
- **サンドボックス最優先**: 全てのファイルアクセスはSecurityScopedBookmarkService経由

## コーディング規約
- 型名: PascalCase (`FileItem`, `FilePaneViewModel`)
- ファイル名: 型名と一致 (1ファイル1主要型)
- ViewController: `〜ViewController` suffix
- ViewModel: `〜ViewModel` suffix
- Service: `〜Service`, `〜Manager`, `〜Queue`
- Protocol: `-ing` or `-able` suffix (`FileSystemProviding`, `DirectoryMonitoring`)

## ドキュメント
- `docs/implementation-plan.md` - 実装プラン
- `docs/plan-review.md` - アーキテクチャレビュー結果

## 前提
- macOS
- Xcode（`xcodebuild` が使えること）

## ビルド・テスト
```bash
cd starfiler-app && xcodebuild -scheme starfiler -configuration Debug build
cd starfiler-app && xcodebuild test -scheme starfiler
```

## /Applications へビルドして使う
```bash
cd /Users/workspace/NilOne/starfiler
./scripts/build_and_install.sh --launch
```
上記で Debug ビルド → `/Applications/Starfiler.app` へ配置 → アプリ起動を自動実行。

## 開発ループ

### 単発で反映
```bash
./scripts/build_and_install.sh --launch
```

### 監視して自動反映
```bash
./scripts/watch_and_install.sh
```
`starfiler-app` 配下のソース変更を監視し、変更検知ごとに自動で再ビルド・再配置。

オプション例:
```bash
./scripts/watch_and_install.sh --no-launch    # 起動なしで反映
./scripts/watch_and_install.sh --interval 2   # 2秒間隔で監視
```

## 主要スクリプト
- `scripts/build_and_install.sh`
- `scripts/watch_and_install.sh`

## 環境変数での上書き
- `SCHEME`（既定: `starfiler`）
- `CONFIGURATION`（既定: `Debug`）
- `DERIVED_DATA_PATH`（既定: `starfiler-app/.derivedData`）
- `APP_DEST`（既定: `/Applications/Starfiler.app`）
