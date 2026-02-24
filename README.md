# Forest Router Tool (FRT)

*Белый список хостов и маршрутизация трафика через VPN или Shadowsocks на роутере.*

**Author:** Rudy Wolf  
**Лицензия:** [Apache 2.0](LICENCE.md) · **История:** [HISTORY.md](HISTORY.md)

---

## Что это

Пакет для роутеров на базе OpenWrt/Entware (Keenetic и др.): трафик к выбранным доменам идёт через туннель. Один список — один маршрут. DNS: dnsmasq + stubby (DoT). AdGuard, Adblock и DNSCrypt не используются.

---

## Схема проекта

```
kvas/
├── Makefile, docker-compose.yml   # Пакет и CI
├── scripts/   build-ipk.sh, ci.sh # Сборка .ipk и полный цикл проверки
├── tests/     run_tests.sh + ...  # Автотесты (список, dnsmasq, add/del)
├── builder/   Docker, Jenkins     # Сборка в контейнере и пайплайн
├── opt/       bin/frt, etc/       # Содержимое пакета (→ /opt на роутере)
└── docs/      Гайды и документация
```

**Детальная структура и назначение каталогов:** [docs/PROJECT-STRUCTURE.md](docs/PROJECT-STRUCTURE.md)

---

## Быстрый старт

| Действие | Команда |
|----------|---------|
| Собрать .ipk (без Docker) | `./scripts/build-ipk.sh --quick` |
| Сборка + тесты + проверка .ipk | `./scripts/ci.sh` или `docker-compose run --rm ci` |
| Установка на роутер | Скопировать .ipk → `opkg install` → **`frt setup`** |

Результат сборки: `./output/frt_*.ipk`.

---

## Управление роутером

- **Команда:** `frt` (устанавливается в `/opt/bin/frt`).
- **Основное:** `frt show` / `frt add <хост>` / `frt del <хост>` / `frt import <файл>` / `frt vpn set` / `frt dns crypt on|off` (DoT через stubby).
- **Справка на устройстве:** `frt help`.

**Подробно:** [docs/ROUTER.md](docs/ROUTER.md) — установка, все подкоманды, структура файлов на роутере.

---

## Автосборщики и тесты

| Раздел | Описание | Гайд |
|--------|----------|------|
| **Сборка** | Быстрая сборка (--quick), Docker, SDK, CI, Jenkins. | [docs/BUILD.md](docs/BUILD.md) |
| **Тесты** | Запуск тестов, сценарии (list_parsing, dnsmasq_generation, host_add_del, error_cases), CI. | [docs/TESTS.md](docs/TESTS.md) |

Кратко:
- **Сборка:** `./scripts/build-ipk.sh --quick` → `output/frt_*.ipk`; полный цикл — `./scripts/ci.sh`.
- **Тесты:** `sh tests/run_tests.sh` (без роутера; вызываются из `ci.sh`).

---

## Требования

- Роутер с [Entware](https://github.com/Entware/Entware) (например, Keenetic).
- Зависимости: jq, curl, dnsmasq-full, ipset, stubby, shadowsocks-libev и др. (см. [Makefile](Makefile)).

---

## Масштабирование (100k+ доменов)

Список обрабатывается потоково; добавление — append, удаление — однопроходное переписывание. Рекомендуется увеличить `dns-forward-max` в dnsmasq (например до 1024). Подробнее — в [docs/ROUTER.md](docs/ROUTER.md).

---

## Документация

| Документ | Содержание |
|----------|------------|
| [docs/README.md](docs/README.md) | Оглавление документации. |
| [docs/PROJECT-STRUCTURE.md](docs/PROJECT-STRUCTURE.md) | Структура репозитория и файлов на роутере. |
| [docs/BUILD.md](docs/BUILD.md) | Сборка и автосборщики. |
| [docs/TESTS.md](docs/TESTS.md) | Тесты. |
| [docs/ROUTER.md](docs/ROUTER.md) | Управление роутером и команда frt. |

---

*— Rudy Wolf*
