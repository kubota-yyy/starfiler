#!/usr/bin/env bash
# Auto-Sync 設定ファイル
# 形式: "IP:SSH_USER:REPO_PATH"

SYNC_TARGETS=(
  "192.168.10.7:eipoc:/Users/workspace/NilOne/starfiler"
  "192.168.10.2:cypher:/Users/workspace/NilOne/starfiler"
  "192.168.10.13:harry:/Users/workspace/NilOne/starfiler"
)

SSH_TIMEOUT=5  # 秒（Mac がスリープ/オフ時のタイムアウト）
