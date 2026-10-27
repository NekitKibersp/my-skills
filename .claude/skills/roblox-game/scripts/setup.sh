#!/usr/bin/env bash
# Ставит rojo (сборка .rbxlx из файлов) и selene (линтер Luau), если их нет.
# Через cargo сборка занимает несколько минут — запускайте в фоне.
set -euo pipefail

export PATH="$HOME/.cargo/bin:$PATH"

missing=()
command -v rojo >/dev/null 2>&1 || missing+=(rojo)
command -v selene >/dev/null 2>&1 || missing+=(selene)

if [ ${#missing[@]} -eq 0 ]; then
  echo "ok: $(rojo --version), $(selene --version)"
  exit 0
fi

if command -v rokit >/dev/null 2>&1; then
  for tool in "${missing[@]}"; do
    case "$tool" in
      rojo) rokit add --global rojo-rbx/rojo ;;
      selene) rokit add --global Kampfkarren/selene ;;
    esac
  done
elif command -v cargo >/dev/null 2>&1; then
  for tool in "${missing[@]}"; do
    echo "cargo install $tool ..."
    cargo install "$tool" --locked
  done
else
  cat >&2 <<'EOF'
Не найдено ни rokit, ни cargo. Установите один из них:
  Rokit (рекомендуется):  https://github.com/rojo-rbx/rokit
  Rust/cargo:             https://rustup.rs
затем запустите этот скрипт снова.
EOF
  exit 1
fi

echo "ok: $(rojo --version), $(selene --version)"
