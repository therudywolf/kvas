#!/usr/bin/env bash
# Сборка .ipk в Linux-контейнере для установки на Keenetic/Entware.
# Решает ошибку opkg "Malformed package file" при сборке под Windows.
# Требуется: Docker Desktop (или Docker + docker-compose).
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/output"
mkdir -p "$OUTPUT_DIR"

echo "Сборка FRT .ipk в Docker (Linux) для Keenetic..."
docker-compose run --rm ci

ipk=$(find "${OUTPUT_DIR}" -maxdepth 1 -name "frt_*.ipk" -type f 2>/dev/null | head -1)
if [ -n "$ipk" ] && [ -f "$ipk" ]; then
  echo ""
  echo "Готово. Пакет для роутера:"
  echo "  $ipk"
  echo "Скопируйте его на Keenetic и выполните: opkg install /path/to/frt_*.ipk"
else
  echo "Ошибка: .ipk не найден в ${OUTPUT_DIR}" >&2
  exit 1
fi
