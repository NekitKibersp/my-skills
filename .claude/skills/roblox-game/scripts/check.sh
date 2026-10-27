#!/usr/bin/env bash
# Собирает проект в .rbxlx и прогоняет selene.
#   check.sh <папка проекта> [выходной.rbxlx]
# Если полный Roblox std для selene скачать нельзя (нет сети), используется
# минимальный список глобальных переменных: синтаксис и логика проверяются, API — нет.
set -euo pipefail

export PATH="$HOME/.cargo/bin:$PATH"

PROJECT="$(cd "${1:?usage: $0 <project-dir> [out.rbxlx]}" && pwd)"
NAME="$(sed -n 's/.*"name": *"\([^"]*\)".*/\1/p' "$PROJECT/default.project.json" | head -1)"
OUT="${2:-$PROJECT/$NAME.rbxlx}"

echo "== rojo build"
rojo build "$PROJECT" -o "$OUT"
scripts=$(grep -c 'name="Source"' "$OUT" || true)
echo "скриптов в плейсе: $scripts"

echo "== selene"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/roblox-game-skill"
mkdir -p "$CACHE"
cd "$CACHE"

if [ ! -f roblox.yml ]; then
  selene generate-roblox-std >/dev/null 2>&1 || true
fi

if [ -f roblox.yml ]; then
  echo 'std = "roblox"' > selene.toml
else
  echo "(нет полного Roblox std — проверка по минимальному списку глобальных переменных)"
  {
    echo "---"
    echo "base: luau"
    echo "globals:"
    for g in game workspace script plugin shared settings Instance Vector3 Vector2 Vector3int16 Vector2int16 \
      CFrame Color3 BrickColor ColorSequence ColorSequenceKeypoint NumberSequence NumberSequenceKeypoint \
      NumberRange UDim UDim2 Rect Region3 Ray RaycastParams OverlapParams PhysicalProperties TweenInfo \
      Enum Random DateTime Font Axes Faces task warn tick time typeof elapsedTime; do
      echo "  $g:"
      echo "    any: true"
    done
  } > roblox_min.yml
  echo 'std = "roblox_min"' > selene.toml
fi

selene "$PROJECT/src"
