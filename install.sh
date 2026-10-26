#!/usr/bin/env bash
# Устанавливает скиллы в ~/.claude/skills, чтобы Claude Code видел их в любом проекте:
#   1. часто обновляемые наборы — свежие, напрямую из их репозиториев
#      (anthropics/skills, heygen-com/hyperframes, emilkowalski/skills, pbakaus/impeccable,
#      elevenlabs/skills);
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
    [ -f "$skill/SKILL.md" ] || continue
    name="$(basename "$skill")"
    rm -rf "${DEST:?}/$name"
    cp -r "$skill" "$DEST/$name"
    echo "installed: $name$label"
  done
}

# Скачивает только папку со скиллами репозитория (по умолчанию skills/, "." — корень)
# и ставит все скиллы из неё (папки с SKILL.md).
install_upstream() {
  local repo="$1" path="${2:-skills}" tmp
  tmp="$(mktemp -d)"
  if git clone --quiet --depth 1 --filter=blob:none --sparse "https://github.com/$repo" "$tmp/r" \
      && if [ "$path" = "." ]; then git -C "$tmp/r" sparse-checkout disable; \
         else git -C "$tmp/r" sparse-checkout set "$path"; fi; then
    install_dir "$tmp/r/$path" " (from $repo)"
  else
    echo "warning: не удалось скачать $repo, его скиллы пропущены" >&2
  fi
  rm -rf "$tmp"
}

install_upstream anthropics/skills
install_upstream heygen-com/hyperframes
install_upstream emilkowalski/skills
install_upstream pbakaus/impeccable plugin/skills
install_upstream elevenlabs/skills .

install_dir "$SRC" ""

# Python-зависимости скиллов (ru-voiceover).
if python3 -m pip install --quiet edge-tts 2>/dev/null \
    || python3 -m pip install --quiet --break-system-packages edge-tts 2>/dev/null; then
  echo "installed: edge-tts (pip)"
else
  echo "warning: не удалось установить edge-tts через pip" >&2
fi

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
