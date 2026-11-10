#!/usr/bin/env bash
# Запускается хуком SessionStart при каждом старте claude (Linux/macOS/Git Bash).
# 1) быстро: git pull + скиллы/агенты/правила из my-skills — сразу;
# 2) раз в сутки в фоне: полная установка (свежие наборы Anthropic и др.).
REPO="$(cd "$(dirname "$0")" && pwd)"
STAMP="$HOME/.claude/.my-skills-full-update"
git -C "$REPO" pull --quiet --ff-only >/dev/null 2>&1 || true
bash "$REPO/install.sh" --local >/dev/null 2>&1 || true
if [ ! -f "$STAMP" ] || [ -n "$(find "$STAMP" -mmin +1440 2>/dev/null)" ]; then
  touch "$STAMP"
  nohup bash "$REPO/install.sh" >/dev/null 2>&1 &
fi
exit 0
