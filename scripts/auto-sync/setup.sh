#!/usr/bin/env bash
# setup.sh — Auto-Syncセットアップスクリプト
# GitHub(origin)へのpush後、他のMacにSSHで自動pullを通知する仕組み
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

echo "=== Starfiler Auto-Sync セットアップ ==="
echo ""

# 1. config.shの存在確認とバリデーション
echo "[1/3] config.sh の確認..."
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE が見つかりません"
  exit 1
fi

source "$CONFIG_FILE"

if [ ${#SYNC_TARGETS[@]} -eq 0 ]; then
  echo "ERROR: SYNC_TARGETS が空です。config.sh を編集してください"
  exit 1
fi

echo "  SYNC_TARGETS: ${#SYNC_TARGETS[@]} 台"
for target in "${SYNC_TARGETS[@]}"; do
  IFS=':' read -r ip user repo_path <<< "$target"
  echo "    - ${user}@${ip}:${repo_path}"
done
echo ""

# 2. 各Macへの疎通テスト
echo "[2/3] SSH疎通テスト..."
ALL_OK=true
for target in "${SYNC_TARGETS[@]}"; do
  IFS=':' read -r ip user repo_path <<< "$target"
  printf "  %-20s ... " "${user}@${ip}"
  if ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" -o BatchMode=yes "${user}@${ip}" "echo ok" 2>/dev/null; then
    echo "OK"
  else
    echo "FAILED"
    ALL_OK=false
  fi
done

if [ "$ALL_OK" = false ]; then
  echo ""
  echo "WARNING: 一部のMacに接続できませんでした（スリープ中の場合は問題ありません）"
fi
echo ""

# 3. auto-pull.sh のローカルテスト
echo "[3/3] auto-pull.sh のローカルテスト..."
if bash "$SCRIPT_DIR/auto-pull.sh"; then
  echo "  ローカルテスト: OK"
else
  echo "  ローカルテスト: FAILED（上記のログを確認してください）"
fi

echo ""
echo "=== セットアップ完了 ==="
echo ""
echo "仕組み:"
echo "  git push origin main → notify-peers.sh → 他のMacにSSHでauto-pull"
echo ""
echo "使い方:"
echo "  /sync             ... pull → コミット → push → 他Mac通知（推奨）"
echo "  手動の場合:"
echo "    git push origin main && bash scripts/auto-sync/notify-peers.sh"
