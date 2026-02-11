# starfiler

macOS向けデュアルペインファイラーのネイティブアプリです。

## 前提

- macOS
- Xcode（`xcodebuild` が使えること）

## `/Applications` へビルドして使う

```bash
cd /Users/workspace/NilOne/starfiler
./scripts/build_and_install.sh --launch
```

上記で以下を自動実行します。

1. `Debug` ビルド
2. `/Applications/Starfiler.app` へ配置
3. アプリ起動

## 修正をすぐ反映する（開発ループ）

### 単発で反映

```bash
cd /Users/workspace/NilOne/starfiler
./scripts/build_and_install.sh --launch
```

コード修正後にこの1コマンドを実行すると、最新ビルドへ即差し替えできます。

### 監視して自動反映

```bash
cd /Users/workspace/NilOne/starfiler
./scripts/watch_and_install.sh
```

`starfiler-app` 配下のソース変更を監視し、変更検知ごとに自動で再ビルド・再配置します。

オプション例:

```bash
# 起動なしで反映
./scripts/watch_and_install.sh --no-launch

# 2秒間隔で監視
./scripts/watch_and_install.sh --interval 2
```

## 主要スクリプト

- `/Users/workspace/NilOne/starfiler/scripts/build_and_install.sh`
- `/Users/workspace/NilOne/starfiler/scripts/watch_and_install.sh`

## 環境変数での上書き

必要に応じて以下を上書きできます。

- `SCHEME`（既定: `starfiler`）
- `CONFIGURATION`（既定: `Debug`）
- `DERIVED_DATA_PATH`（既定: `starfiler-app/.derivedData`）
- `APP_DEST`（既定: `/Applications/Starfiler.app`）
