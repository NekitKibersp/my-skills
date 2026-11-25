#!/usr/bin/env bash
# Создать проект Visual Studio (C++, консоль) из шаблона и положить в него .cpp
# new_vs_project.sh <папка_работы> <ИмяПроекта> <файл.cpp>
set -euo pipefail
OUT="$1"; NAME="$2"; CPP="$3"
T="$(cd "$(dirname "$0")/../assets/vs-template" && pwd)"
GUID=$(python3 -c "import uuid;print(uuid.uuid4())")
mkdir -p "$OUT/$NAME/$NAME"
sed "s/__NAME__/$NAME/g" "$T/Project.slnx" > "$OUT/$NAME/$NAME.slnx"
for e in vcxproj vcxproj.filters vcxproj.user; do
  sed -e "s/__NAME__/$NAME/g" -e "s/__GUID__/$GUID/g" "$T/Project.$e" > "$OUT/$NAME/$NAME/$NAME.$e"
done
# VS по умолчанию сохраняет .cpp в UTF-8 с BOM — без BOM русский текст в консоли станет кракозябрами
python3 - "$CPP" "$OUT/$NAME/$NAME/$NAME.cpp" <<'PY'
import sys
s = open(sys.argv[1], encoding='utf-8-sig').read()
open(sys.argv[2], 'w', encoding='utf-8-sig', newline='\r\n').write(s)
PY
echo "$OUT/$NAME"
