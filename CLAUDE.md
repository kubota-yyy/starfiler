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

## ビルド・テスト
```bash
cd starfiler-app && xcodebuild -scheme starfiler -configuration Debug build
cd starfiler-app && xcodebuild test -scheme starfiler
```
