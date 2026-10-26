#!/usr/bin/env bash
# Устанавливает скиллы в ~/.claude/skills, чтобы Claude Code видел их в любом проекте:
#   1. все скиллы Anthropic — свежие, напрямую из официального anthropics/skills;
#   2. сторонние скиллы из этого репозитория (.claude/skills).
#
# Локально:        ./install.sh
# Облачный setup:  git clone --depth 1 https://github.com/NekitKibersp/my-skills /tmp/my-skills && /tmp/my-skills/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/.claude/skills"
DEST="$HOME/.claude/skills"
mkdir -p "$DEST"

install_dir() {
  local dir="$1" label="$2" name
  for skill in "$dir"/*/; do
    name="$(basename "$skill")"
    rm -rf "${DEST:?}/$name"
    cp -r "$skill" "$DEST/$name"
    echo "installed: $name$label"
  done
}

TMP="$(mktemp -d)"
if git clone --quiet --depth 1 https://github.com/anthropics/skills "$TMP/anthropic"; then
  install_dir "$TMP/anthropic/skills" " (from anthropics/skills)"
else
  echo "warning: не удалось скачать anthropics/skills, скиллы Anthropic пропущены" >&2
fi
rm -rf "$TMP"

install_dir "$SRC" ""

# Общие инструкции для Claude: блок между маркерами в ~/.claude/CLAUDE.md
# обновляется при каждом запуске, остальное содержимое файла не трогаем.
INSTR="$(cd "$(dirname "$0")" && pwd)/user-instructions.md"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
BEGIN="<!-- my-skills:begin -->"
END="<!-- my-skills:end -->"
touch "$CLAUDE_MD"
sed -i "/$BEGIN/,/$END/d" "$CLAUDE_MD"
{ echo "$BEGIN"; cat "$INSTR"; echo "$END"; } >> "$CLAUDE_MD"
echo "installed: user instructions -> $CLAUDE_MD"
