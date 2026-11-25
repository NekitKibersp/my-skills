#!/usr/bin/env bash
# Проверить, что .cpp собирается и работает (Linux, g++, заглушка windows.h).
# check_cpp.sh <файл.cpp> [входные данные через \n]
set -euo pipefail
STUB="$(cd "$(dirname "$0")/../assets/vs-template/stub" && pwd)"
B=$(mktemp -d)
g++ -std=c++17 -Wall -I"$STUB" "$1" -o "$B/a.out"
printf "${2:-}" | (cd "$B" && ./a.out)
echo; echo "[код возврата: $?]"
