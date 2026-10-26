#!/usr/bin/env bash
# Устанавливает скиллы в ~/.claude/skills, чтобы Claude Code видел их в любом проекте:
#   1. часто обновляемые наборы — свежие, напрямую из их репозиториев
#      (anthropics/skills, heygen-com/hyperframes, emilkowalski/skills);
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

# Скачивает только папку skills/ репозитория и ставит все скиллы из неё.
install_upstream() {
  local repo="$1" tmp
  tmp="$(mktemp -d)"
  if git clone --quiet --depth 1 --filter=blob:none --sparse "https://github.com/$repo" "$tmp/r" \
      && git -C "$tmp/r" sparse-checkout set skills; then
    install_dir "$tmp/r/skills" " (from $repo)"
  else
    echo "warning: не удалось скачать $repo, его скиллы пропущены" >&2
  fi
  rm -rf "$tmp"
}

install_upstream anthropics/skills
install_upstream heygen-com/hyperframes
install_upstream emilkowalski/skills

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
