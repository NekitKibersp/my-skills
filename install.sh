#!/usr/bin/env bash
# Устанавливает скиллы в ~/.claude/skills, чтобы Claude Code видел их в любом проекте:
#   1. часто обновляемые наборы — свежие, напрямую из их репозиториев
#      (anthropics/skills, heygen-com/hyperframes, emilkowalski/skills, pbakaus/impeccable,
#      elevenlabs/skills, remotion-dev/skills);
#   2. сторонние скиллы из этого репозитория (.claude/skills);
#   3. субагенты из этого репозитория (.claude/agents) -> ~/.claude/agents.
#
# Локально:        ./install.sh            (полная установка)
#                  ./install.sh --hook     (+ автообновление при каждом запуске claude, Linux/macOS)
#                  ./install.sh --local    (быстро: только скиллы/агенты/правила из этого репозитория)
# Windows:         install.ps1 (ставит всё и сам прописывает хук автообновления)
# Облачный setup:  git clone --depth 1 https://github.com/NekitKibersp/my-skills /tmp/my-skills && /tmp/my-skills/install.sh
set -euo pipefail

LOCAL_ONLY=0
WITH_HOOK=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL_ONLY=1 ;;
    --hook) WITH_HOOK=1 ;;
  esac
done
REPO="$(cd "$(dirname "$0")" && pwd)"

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

if [ "$LOCAL_ONLY" = 0 ]; then
  install_upstream anthropics/skills
  install_upstream heygen-com/hyperframes
  install_upstream emilkowalski/skills
  install_upstream pbakaus/impeccable plugin/skills
  install_upstream elevenlabs/skills .
  install_upstream remotion-dev/skills
fi

install_dir "$SRC" ""

# Субагенты (.claude/agents) -> ~/.claude/agents.
AGENTS_SRC="$(cd "$(dirname "$0")" && pwd)/.claude/agents"
mkdir -p "$HOME/.claude/agents"
for agent in "$AGENTS_SRC"/*.md; do
  [ -f "$agent" ] || continue
  cp "$agent" "$HOME/.claude/agents/"
  echo "installed agent: $(basename "$agent" .md)"
done

# Python-зависимости скиллов: edge-tts (ru-voiceover), python-docx (title-page, рефераты).
if [ "$LOCAL_ONLY" = 0 ]; then
  PY="$(command -v python3 || command -v python || true)"
  if [ -n "$PY" ] && { "$PY" -m pip install --quiet edge-tts python-docx 2>/dev/null \
      || "$PY" -m pip install --quiet --break-system-packages edge-tts python-docx 2>/dev/null; }; then
    echo "installed: edge-tts, python-docx (pip)"
  else
    echo "warning: не удалось установить edge-tts и python-docx через pip" >&2
  fi
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

# Хук автообновления: при каждом запуске claude подтягивает my-skills (см. update.sh).
if [ "$WITH_HOOK" = 1 ]; then
  PY="$(command -v python3 || command -v python || true)"
  if [ -z "$PY" ]; then
    echo "warning: нет python — хук не прописан" >&2
  else
    "$PY" - "$HOME/.claude/settings.json" "bash \"$REPO/update.sh\"" <<'PYEOF'
import json, os, sys
path, cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    with open(path, encoding="utf-8-sig") as f:
        txt = f.read().strip()
    data = json.loads(txt) if txt else {}
hooks = data.setdefault("hooks", {})
entries = [e for e in hooks.get("SessionStart", [])
           if not any("my-skills" in h.get("command", "") for h in e.get("hooks", []))]
entries.append({"hooks": [{"type": "command", "command": cmd, "timeout": 60}]})
hooks["SessionStart"] = entries
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
print("installed: SessionStart hook ->", path)
PYEOF
  fi
fi
