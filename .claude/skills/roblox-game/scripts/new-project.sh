#!/usr/bin/env bash
# Создаёт новый Rojo-проект из шаблона.
#   new-project.sh <папка> [ИмяИгры]
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <dir> [GameName]" >&2
  exit 1
fi

DIR="$1"
NAME="${2:-$(basename "$DIR")}"
TEMPLATE="$(cd "$(dirname "$0")/../template" && pwd)"

if [ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ]; then
  echo "error: $DIR уже существует и не пуст" >&2
  exit 1
fi

mkdir -p "$DIR"
cp -r "$TEMPLATE"/. "$DIR"/
sed -i.bak "s/\"GameName\"/\"$NAME\"/" "$DIR/default.project.json" && rm -f "$DIR/default.project.json.bak"

echo "created $DIR ($NAME)"
find "$DIR" -type f | sort
