#!/usr/bin/env bash
# notify-peers.sh — push後に他のMacへauto-pullを通知する
# 使い方: git push後にこのスクリプトを実行、またはgit pushのラッパーとして使う
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# 自分のIPアドレスを取得（en0 のIPv4）
MY_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "")

for target in "${SYNC_TARGETS[@]}"; do
  IFS=':' read -r ip user repo_path <<< "$target"

  # 自分自身はスキップ
  if [ "$ip" = "$MY_IP" ]; then
    continue
  fi

  # バックグラウンドでSSH経由のauto-pullを実行
  ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" \
      -o StrictHostKeyChecking=no \
      -o BatchMode=yes \
      "${user}@${ip}" \
      "cd ${repo_path} && bash scripts/auto-sync/auto-pull.sh" \
      >> /tmp/starfiler-auto-sync-notify.log 2>&1 &
done

# バックグラウンドジョブの完了を待たない
exit 0
