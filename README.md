# Forest Router Tool (FRT)

Пакет для роутеров на базе OpenWrt/Entware (Keenetic и др.). Обеспечивает VPN/Shadowsocks и «белый список» хостов: трафик к выбранным доменам идёт через туннель. При обращении к любому хосту из списка весь трафик идёт через настроенное VPN или Shadowsocks-соединение.

- **Лицензия:** Apache License 2.0 (см. [LICENCE.md](LICENCE.md))
- **История изменений:** [HISTORY.md](HISTORY.md)

## Требования

- Роутер с [Entware](https://github.com/Entware/Entware) (например, Keenetic).
- Зависимости пакета: **jq**, **curl**, **dnsmasq-full**, **ipset**, **stubby** (DNS over TLS), **shadowsocks-libev** и др. (указываются в [Makefile](Makefile)).
- DNS: dnsmasq — кэширующий резолвер с правилами ipset по списку FRT; upstream — **stubby** (DoT). Пакеты AdGuard, Adblock и DNSCrypt не используются.

## Сборка .ipk

Собранный пакет имеет формат **.ipk** и устанавливается на роутер через `opkg install`.

### Локальная сборка скриптом (рекомендуется)

В корне репозитория:

```bash
./scripts/build-ipk.sh [OPTIONS]
```

**Режимы:**

1. **Docker (по умолчанию)** — если Docker установлен и образ ещё не собран, он будет собран автоматически. Репозиторий и каталог `./output` монтируются в контейнер; после сборки .ipk появляется в `./output`.

   ```bash
   ./scripts/build-ipk.sh
   # или явно
   ./scripts/build-ipk.sh --docker
   ```

2. **Через Entware SDK** — если уже развёрнуто дерево сборки Entware (см. [инструкции Entware](https://github.com/Entware/Entware)), можно собрать только пакет без Docker:

   ```bash
   export TOPDIR=/path/to/entware/root
   ./scripts/build-ipk.sh --sdk
   ```

**Опции:**

- `-o DIR` — каталог для .ipk (по умолчанию `./output`).
- `--help` — справка.

**Переменные окружения:** `TOPDIR`, `DOCKER_IMAGE`, `OUTPUT_DIR`, `ENTWARE_REPO_URL`, `BUILD_PATH`, `MAKE_JOBS` (только для SDK).

### Сборка в CI (Jenkins)

В [builder/](builder/) находятся:

- **Dockerfile** — образ для сборки Entware и пакета.
- **Jenkinsfile** — пайплайн: сборка образа, сборка toolchain и пакета, копирование .ipk в `output/`, опционально копирование на роутер и релиз на GitHub.
- **builder** — скрипт внутри контейнера: `all` (toolchain + пакет), `tools` (только подготовка дерева), `app` (только пакет при уже собранном дереве).

Артефакты .ipk сохраняются в каталог `output/` рабочей области и архивируются в Jenkins.

## Установка на роутер

1. Скопируйте .ipk на роутер (например, в `/opt/tmp/`).
2. Установите: `opkg install /opt/tmp/frt_*.ipk`
3. Настройка: **`frt setup`**

## Большие списки (100k+ доменов)

- Список обрабатывается потоково; добавление — append в `frt.list`; удаление — однопроходное переписывание файла (без множественных `sed -i`).
- В `dnsmasq.conf` увеличен `dns-forward-max` (например до 1024) для высокой нагрузки.
- Массовое предразрешение всех доменов в ipset не выполняется — домены попадают в ipset через dnsmasq при запросе.

## Тесты

В каталоге [tests/](tests/):

- `run_tests.sh` — запуск всех тестов (парсинг списка, генерация dnsmasq, добавление/удаление хостов).
- Запуск: в среде с `sh` (Linux, Git Bash, WSL): `sh tests/run_tests.sh`

В CI можно добавить шаг: `sh tests/run_tests.sh` после сборки пакета.

## Структура репозитория

- **Makefile** — описание пакета OpenWrt/Entware (версия, зависимости, install/postinst).
- **opt/** — файлы пакета: скрипты (`bin/`, `etc/init.d/`, `etc/ndm/`), конфиги (`etc/conf/`).
- **tests/** — тесты (парсинг списка, генерация dnsmasq, add/del хостов).
- **builder/** — окружение и скрипты для сборки (Docker, Jenkins, скрипт `builder`).
- **scripts/** — вспомогательные скрипты (например, `build-ipk.sh`).
