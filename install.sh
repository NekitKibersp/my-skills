#!/usr/bin/env bash
# Устанавливает скиллы из этого репозитория в ~/.claude/skills,
# чтобы Claude Code видел их в любом проекте.
#
# Локально:        ./install.sh
# Облачный setup:  git clone --depth 1 https://github.com/<you>/claude-skills /tmp/claude-skills && /tmp/claude-skills/install.sh
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)/.claude/skills"
DEST="$HOME/.claude/skills"
mkdir -p "$DEST"

for dir in "$SRC"/*/; do
  name="$(basename "$dir")"
  rm -rf "${DEST:?}/$name"
  cp -r "$dir" "$DEST/$name"
  echo "installed: $name"
done

# docx/pdf/pptx/xlsx под проприетарной лицензией Anthropic, поэтому их нет
# в этом репозитории: скачиваем напрямую из официального anthropics/skills.
TMP="$(mktemp -d)"
if git clone --quiet --depth 1 https://github.com/anthropics/skills "$TMP/anthropic"; then
  for name in docx pdf pptx xlsx; do
    rm -rf "${DEST:?}/$name"
    cp -r "$TMP/anthropic/skills/$name" "$DEST/$name"
    echo "installed: $name (from anthropics/skills)"
  done
else
  echo "warning: не удалось скачать anthropics/skills, docx/pdf/pptx/xlsx пропущены" >&2
fi
rm -rf "$TMP"
