#!/usr/bin/env bash
# setup.sh — Auto-Syncセットアップスクリプト
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

GIT_SERVER="192.168.10.13"
GIT_SERVER_USER="harry"
GIT_SERVER_REPO="/Users/harry/git-server/starfiler.git"
GIT_SERVER_HOOK_DIR="$GIT_SERVER_REPO/hooks"

echo "=== Starfiler Auto-Sync セットアップ ==="
echo ""

# 1. config.shの存在確認とバリデーション
echo "[1/6] config.sh の確認..."
if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: $CONFIG_FILE が見つかりません"
  exit 1
fi

source "$CONFIG_FILE"

if [ ${#SYNC_TARGETS[@]} -eq 0 ]; then
  echo "ERROR: SYNC_TARGETS が空です。config.sh を編集してください"
  exit 1
fi

# プレースホルダーチェック
for target in "${SYNC_TARGETS[@]}"; do
  if [[ "$target" == *"XX"* ]] || [[ "$target" == *"YY"* ]] || [[ "$target" == *"ZZ"* ]]; then
    echo "ERROR: config.sh にプレースホルダーが残っています: $target"
    echo "各MacのIP・ユーザー名・パスを記入してください"
    exit 1
  fi
done

echo "  SYNC_TARGETS: ${#SYNC_TARGETS[@]} 台"
for target in "${SYNC_TARGETS[@]}"; do
  IFS=':' read -r ip user repo_path <<< "$target"
  echo "    - ${user}@${ip}:${repo_path}"
done
echo ""

# 2. 各Macへの疎通テスト
echo "[2/6] SSH疎通テスト..."
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
  read -p "続行しますか？ [y/N] " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi
echo ""

# 3. gitサーバーへの疎通テスト
echo "[3/6] Gitサーバー疎通テスト..."
printf "  %s@%s ... " "$GIT_SERVER_USER" "$GIT_SERVER"
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${GIT_SERVER_USER}@${GIT_SERVER}" "echo ok" 2>/dev/null; then
  echo "OK"
else
  echo "FAILED"
  echo "ERROR: Gitサーバーに接続できません"
  exit 1
fi
echo ""

# 4. gitサーバーにbare repoを作成（なければ）
echo "[4/6] Gitサーバーにbare repoを準備..."
ssh "${GIT_SERVER_USER}@${GIT_SERVER}" "
  if [ -d ${GIT_SERVER_REPO} ]; then
    echo '  bare repo は既に存在します'
  else
    echo '  bare repo を作成中...'
    mkdir -p $(dirname ${GIT_SERVER_REPO})
    git init --bare ${GIT_SERVER_REPO}
    echo '  作成完了: ${GIT_SERVER_REPO}'
  fi
"
echo ""

# 5. post-receiveフックとconfig.shをgitサーバーにコピー
echo "[5/6] フックをgitサーバーにデプロイ..."

# 既存のpost-receiveフックをバックアップ
ssh "${GIT_SERVER_USER}@${GIT_SERVER}" "
  if [ -f ${GIT_SERVER_HOOK_DIR}/post-receive ]; then
    cp ${GIT_SERVER_HOOK_DIR}/post-receive ${GIT_SERVER_HOOK_DIR}/post-receive.bak.\$(date +%Y%m%d%H%M%S)
    echo '  既存のpost-receiveをバックアップしました'
  fi
"

# config.shをコピー
scp "$CONFIG_FILE" "${GIT_SERVER_USER}@${GIT_SERVER}:${GIT_SERVER_HOOK_DIR}/auto-sync-config.sh"
echo "  config.sh → ${GIT_SERVER_HOOK_DIR}/auto-sync-config.sh"

# post-receiveをデプロイ
ssh "${GIT_SERVER_USER}@${GIT_SERVER}" "
  EXISTING_HOOK='${GIT_SERVER_HOOK_DIR}/post-receive'
  if [ -f \"\$EXISTING_HOOK\" ] && grep -q 'auto-sync' \"\$EXISTING_HOOK\" 2>/dev/null; then
    echo '  auto-syncフックは既に存在します（スキップ）'
  elif [ -f \"\$EXISTING_HOOK\" ]; then
    echo '' >> \"\$EXISTING_HOOK\"
    echo '# === Auto-Sync Hook ===' >> \"\$EXISTING_HOOK\"
    cat >> \"\$EXISTING_HOOK\"
  else
    cat > \"\$EXISTING_HOOK\"
  fi
  chmod +x \"\$EXISTING_HOOK\"
" < "$SCRIPT_DIR/post-receive"
echo "  post-receive → ${GIT_SERVER_HOOK_DIR}/post-receive"
echo "  実行権限を付与しました"
echo ""

# 6. ローカルのorigin をgitサーバーに変更し、GitHubをgithub リモートに
echo "[6/6] ローカルのgitリモートを設定..."
cd "$REPO_DIR"

CURRENT_ORIGIN=$(git remote get-url origin 2>/dev/null || echo "")
LOCAL_SERVER_URL="ssh://${GIT_SERVER_USER}@${GIT_SERVER}${GIT_SERVER_REPO}"

if [ "$CURRENT_ORIGIN" = "$LOCAL_SERVER_URL" ]; then
  echo "  origin は既にローカルサーバーです"
else
  if [ -n "$CURRENT_ORIGIN" ]; then
    # 現在のoriginが GitHub なら github リモートとして残す
    if echo "$CURRENT_ORIGIN" | grep -q "github.com"; then
      if ! git remote get-url github &>/dev/null; then
        git remote add github "$CURRENT_ORIGIN"
        echo "  GitHub を 'github' リモートとして保存: $CURRENT_ORIGIN"
      fi
    fi
    git remote set-url origin "$LOCAL_SERVER_URL"
    echo "  origin → $LOCAL_SERVER_URL"
  else
    git remote add origin "$LOCAL_SERVER_URL"
    echo "  origin を追加: $LOCAL_SERVER_URL"
  fi
fi

# ローカルサーバーに初回pushして同期
echo "  初回pushを実行..."
if git push -u origin main 2>&1; then
  echo "  初回push完了"
else
  echo "  初回pushに失敗しました（上記のログを確認してください）"
fi
echo ""

echo "=== セットアップ完了 ==="
echo ""
echo "リモート構成:"
git remote -v
echo ""
echo "検証手順:"
echo "  1. このMacで何かファイルを変更して git push"
echo "  2. 他のMacでmacOS通知が来ることを確認"
echo "  3. 他のMacで git log -1 して最新コミットを確認"
echo ""
echo "GitHubへのpushは別途:"
echo "  git push github main"
