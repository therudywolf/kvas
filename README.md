# Forest Router Tool (FRT)

*Белый список хостов и маршрутизация трафика через VPN или Shadowsocks на роутере.*

**Author:** Rudy Wolf

---

Пакет для роутеров на базе OpenWrt/Entware (Keenetic и др.): трафик к выбранным доменам идёт через туннель. Один список — один маршрут.

- **Лицензия:** Apache License 2.0 — [LICENCE.md](LICENCE.md)
- **История:** [HISTORY.md](HISTORY.md)

---

## Требования

- Роутер с [Entware](https://github.com/Entware/Entware) (например, Keenetic).
- Зависимости: **jq**, **curl**, **dnsmasq-full**, **ipset**, **stubby** (DoT), **shadowsocks-libev** и др. (см. [Makefile](Makefile)).
- DNS: **dnsmasq** + **stubby** (DNS over TLS). AdGuard, Adblock и DNSCrypt не используются.

---

## Сборка .ipk

### Быстрая сборка (без Docker и SDK)

Для пакета с `PKGARCH:=all` достаточно упаковать `opt/` и служебные файлы:

```bash
./scripts/build-ipk.sh --quick
# или
./scripts/build-ipk.sh --pack-only
```

Требуется утилита `ar` (binutils). Результат: `./output/frt_*.ipk`. На Windows запускайте через `bash scripts/build-ipk.sh --quick` (WSL или Git Bash), не через PowerShell.

### Сборка через Docker или SDK

```bash
./scripts/build-ipk.sh [OPTIONS]
```

- **Docker** (по умолчанию) — образ собирается при первом запуске, .ipk в `./output`.
- **SDK** — при заданном `TOPDIR`: `export TOPDIR=/path/to/entware && ./scripts/build-ipk.sh --sdk`.

Опции: `-o DIR` (каталог для .ipk), `-h` / `--help`.

### Проверка перед заливкой на роутер

Перед установкой пакета на роутер рекомендуется выполнить полный цикл: сборка, тесты, проверка структуры .ipk.

**Локально:**
```bash
./scripts/ci.sh
# или с режимом: ./scripts/ci.sh --docker
```

**В Docker (воспроизводимая среда):**
```bash
docker-compose run --rm ci
```

При успехе выводится «Ready for upload. .ipk in ./output/» — пакет готов к копированию на роутер и установке через `opkg install`.

### CI (Jenkins)

В [builder/](builder/) — Dockerfile, Jenkinsfile, скрипт `builder`. Артефакты в `output/`.

---

## Установка на роутер

1. Скопируйте .ipk на роутер (например, в `/opt/tmp/`).
2. `opkg install /opt/tmp/frt_*.ipk`
3. **`frt setup`** — первичная настройка.

---

## Масштабирование (100k+ доменов)

- **Список:** потоковое чтение `frt.list` (один проход), добавление — append, удаление — однопроходное переписывание файла (`grep -v -F -x`), без загрузки всего списка в память.
- **Генерация frt.dnsmasq:** однопроходная запись строк `ipset=/домен/FRT_LIST`; при отсутствии `frt.list` — пустой вывод без ошибки.
- **dnsmasq:** рекомендуется `dns-forward-max` 1024 и выше при больших списках; домены попадают в ipset по мере запросов через dnsmasq, без предразрешения всех доменов в IP.
- **ipset:** используется ttl; массовое предразрешение 100k доменов в IP не выполняется — резолв по требованию через dnsmasq.

---

## Тесты

```bash
sh tests/run_tests.sh
```

В [tests/](tests/): парсинг списка, генерация dnsmasq, добавление/удаление хостов, граничные случаи. Запуск в среде с `sh` (Linux, Git Bash, WSL). В CI можно добавить шаг после сборки.

---

## Структура репозитория

| Каталог / файл | Назначение |
|----------------|------------|
| **Makefile** | Пакет OpenWrt/Entware (версия, зависимости, install/postinst). |
| **opt/** | Файлы пакета: скрипты (`bin/`, `etc/init.d/`, `etc/ndm/`), конфиги (`etc/conf/`). |
| **tests/** | Тесты (список, dnsmasq, add/del, error_cases). |
| **scripts/** | Сборка: `build-ipk.sh` (в т.ч. `--quick`), `postinst.in`. |
| **builder/** | Docker, Jenkins, скрипт сборки в контейнере. |

---

*— Rudy Wolf*
