#!/usr/bin/env bash
# auto-pull.sh — 各Macで実行される安全なpullスクリプト
# コンフリクト時は Claude Code の /sync pull スキルに委譲する
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK_FILE="/tmp/starfiler-auto-pull.lock"
LOG_FILE="$HOME/.starfiler-auto-sync.log"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

notify() {
  osascript -e "display notification \"$1\" with title \"Starfiler Sync\"" 2>/dev/null || true
}

cleanup() {
  rm -f "$LOCK_FILE"
}

# claude CLI のパスを解決（SSH経由だとPATHが通らないことがある）
find_claude() {
  if command -v claude &>/dev/null; then
    echo "claude"
    return 0
  fi
  for p in "$HOME/.local/bin/claude" "/usr/local/bin/claude" "$HOME/.claude/bin/claude"; do
    if [ -x "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

# ロックファイルで二重実行防止
if [ -f "$LOCK_FILE" ]; then
  # 古いロック（5分以上）は無視
  if [ "$(find "$LOCK_FILE" -mmin +5 2>/dev/null)" ]; then
    rm -f "$LOCK_FILE"
  else
    log "SKIP: 別のauto-pullが実行中"
    exit 0
  fi
fi
echo $$ > "$LOCK_FILE"
trap cleanup EXIT

cd "$REPO_DIR"

# rebase/merge進行中なら中止
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ] || [ -f ".git/MERGE_HEAD" ]; then
  log "SKIP: rebaseまたはmergeが進行中"
  notify "Sync スキップ: rebase/merge進行中"
  exit 0
fi

# uncommitted changesをstash（untracked含む）
# git status --porcelain で確実に検出し、stash前後のカウントで作成有無を判定
STASHED=false
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  STASH_COUNT_BEFORE=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  log "INFO: uncommitted changesをstash（untracked含む）"
  git stash push -u -m "auto-sync-stash-$(date '+%Y%m%d-%H%M%S')" 2>&1 | tee -a "$LOG_FILE" || true
  STASH_COUNT_AFTER=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  if [ "$STASH_COUNT_AFTER" -gt "$STASH_COUNT_BEFORE" ]; then
    STASHED=true
  fi
fi

# pull --rebase（高速パス：コンフリクトがなければこれだけで完了）
log "INFO: git pull --rebase origin main"
PULL_OUTPUT=$(git pull --rebase origin main 2>&1) || true
echo "$PULL_OUTPUT" | tee -a "$LOG_FILE"

# pull成功判定
if echo "$PULL_OUTPUT" | grep -qE '(Already up to date|Fast-forward|Successfully rebased)'; then
  # 成功
  if [ "$STASHED" = true ]; then
    if git stash pop 2>&1 | tee -a "$LOG_FILE"; then
      log "OK: pull成功（stash復元済み）"
      notify "Sync完了（stash復元済み）"
    else
      log "WARN: stash popでコンフリクト発生"
      git checkout -- . 2>/dev/null || true
      git stash drop 2>/dev/null || true
      notify "Sync完了だがstash復元に失敗。手動確認してください"
    fi
  else
    log "OK: pull成功"
    notify "Sync完了"
  fi
  exit 0
fi

# --- ここからコンフリクト/エラー発生時の処理 ---
log "WARN: pull失敗。/sync pull に委譲します"
notify "Syncコンフリクト検出。Claude Code /sync pull で自動解決中..."

# 進行中のrebaseを中止して元の状態に戻す
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
  git rebase --abort 2>&1 | tee -a "$LOG_FILE" || true
fi

# stashを復元（/sync pull が改めてstash管理するため）
if [ "$STASHED" = true ]; then
  git stash pop 2>&1 | tee -a "$LOG_FILE" || true
  STASHED=false
fi

# Claude Code の /sync pull スキルに委譲
CLAUDE_BIN=$(find_claude) || true
if [ -z "$CLAUDE_BIN" ]; then
  log "ERROR: claude CLIが見つかりません。手動で解決してください"
  notify "Syncコンフリクト。claude CLIが見つかりません"
  exit 1
fi

log "INFO: claude /sync pull を実行"
if "$CLAUDE_BIN" -p "/sync pull" \
    --allowedTools 'Read,Write,Edit,Glob,Grep,Bash(git *)' \
    2>&1 | tee -a "$LOG_FILE"; then
  # /sync pull 完了後の状態確認
  if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ] || [ -f ".git/MERGE_HEAD" ]; then
    log "ERROR: /sync pull 後もrebase/mergeが残っています"
    git rebase --abort 2>&1 | tee -a "$LOG_FILE" || true
    notify "Syncコンフリクト自動解決失敗。手動で解決してください"
    exit 1
  fi
  log "OK: /sync pull でコンフリクト解決完了"
  notify "Sync完了（/sync pull で自動解決）"
else
  log "ERROR: /sync pull が失敗しました"
  # 安全のためrebaseが残っていれば中止
  if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    git rebase --abort 2>&1 | tee -a "$LOG_FILE" || true
  fi
  notify "Syncコンフリクト自動解決失敗。手動で解決してください"
  exit 1
fi
