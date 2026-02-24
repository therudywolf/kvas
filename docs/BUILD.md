# Сборка .ipk и автосборщики

## Обзор

- **Быстрая сборка (pack-only):** без Docker и без Entware SDK — упаковка `opt/` и служебных файлов в .ipk. Требуется только `ar` (binutils).
- **Полный цикл перед заливкой на роутер:** сборка → тесты → проверка .ipk (один скрипт или Docker).

## Быстрая сборка (без Docker/SDK)

Для пакета с `PKGARCH:=all` достаточно упаковать данные:

```bash
./scripts/build-ipk.sh --quick
# или
./scripts/build-ipk.sh --pack-only
```

- Требуется: утилита **ar** (пакет binutils).
- Результат: `./output/frt_<version>-<release>_all.ipk`.
- На Windows: запускать через **bash** (WSL или Git Bash): `bash scripts/build-ipk.sh --quick`, не через PowerShell.

## Сборка через Docker или SDK

```bash
./scripts/build-ipk.sh [OPTIONS]
```

| Режим | Когда используется | Результат |
|-------|--------------------|-----------|
| **--docker** | По умолчанию, если не задан TOPDIR | Образ собирается при первом запуске, .ipk в `./output`. |
| **--sdk** | Задан `TOPDIR` (корень Entware SDK) | `make package/frt/compile`, .ipk копируется в `./output`. |

Опции: `-o DIR` (каталог для .ipk), `-h` / `--help`.

Пример с SDK:
```bash
export TOPDIR=/path/to/entware
./scripts/build-ipk.sh --sdk
```

## Автосборщик и проверка перед заливкой на роутер

Перед установкой пакета на роутер рекомендуется выполнить полный цикл: **сборка → тесты → валидация .ipk**.

### Локально

```bash
./scripts/ci.sh
# или с режимом сборки:
./scripts/ci.sh --docker
CI_BUILD_MODE=sdk ./scripts/ci.sh
```

- Шаг 1: сборка .ipk (по умолчанию `--quick`).
- Шаг 2: запуск `tests/run_tests.sh`.
- Шаг 3: проверка структуры .ipk (ar, control: Package, Architecture).
- При успехе: сообщение «Ready for upload. .ipk in ./output/» и exit 0.

### В Docker (воспроизводимая среда)

```bash
docker-compose run --rm ci
```

- Используется образ из `builder/Dockerfile.ci` (debian:11-slim + binutils + bash).
- Монтируется корень репозитория; выполняется `./scripts/ci.sh --quick`.
- Артефакт .ipk появляется в `./output` на хосте.

## CI (Jenkins)

В каталоге **builder/**:

- **Dockerfile** — образ для полной сборки Entware.
- **Dockerfile.ci** — лёгкий образ для шага «сборка + тесты».
- **Jenkinsfile** — пайплайн (сборка образа, сборка пакета, копирование на роутер, тесты и т.д.).
- **builder** — скрипт, выполняемый внутри контейнера (make, копирование .ipk в `OUTPUT_DIR`).

Артефакты сборки ожидаются в `output/` (монтируется в контейнер как `/output`).

## Краткая схема

```
Локально:
  build-ipk.sh --quick     → output/frt_*.ipk
  ci.sh                    → build → tests → validate .ipk → "Ready for upload"

Docker:
  docker-compose run --rm ci   → то же, в контейнере

SDK:
  TOPDIR=... build-ipk.sh --sdk   → output/frt_*.ipk
```

Подробнее о тестах: [TESTS.md](TESTS.md).
