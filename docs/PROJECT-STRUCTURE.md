# Структура проекта FRT

## Схема репозитория

```
kvas/
├── Makefile              # Пакет OpenWrt/Entware: версия, зависимости, install/postinst
├── docker-compose.yml    # CI: один сервис ci (сборка + тесты)
├── HISTORY.md            # История изменений
├── LICENCE.md            # Apache 2.0
├── README.md             # Обзор и быстрый старт (детали — в docs/)
│
├── docs/                 # Гайды и документация
│   ├── README.md         # Оглавление docs
│   ├── PROJECT-STRUCTURE.md  # Этот файл
│   ├── BUILD.md          # Сборка и автосборщики
│   ├── TESTS.md          # Тесты
│   └── ROUTER.md         # Управление роутером
│
├── scripts/              # Сборка .ipk и CI
│   ├── build-ipk.sh      # Сборка: --quick | --docker | --sdk
│   ├── ci.sh             # Полный цикл: сборка → тесты → валидация .ipk
│   └── postinst.in       # Шаблон postinst (подстановка версии)
│
├── tests/                # Автотесты (список, dnsmasq, add/del, граничные случаи)
│   ├── run_tests.sh      # Точка входа: запуск всех тестов
│   ├── env.sh            # Переменные окружения тестов
│   ├── list_parsing.sh
│   ├── dnsmasq_generation.sh
│   ├── host_add_del.sh
│   └── error_cases.sh
│
├── builder/              # Сборка в Docker и Jenkins
│   ├── Dockerfile        # Образ для полной сборки Entware
│   ├── Dockerfile.ci     # Лёгкий образ для CI (binutils + bash)
│   ├── Jenkinsfile       # Пайплайн Jenkins
│   └── builder           # Скрипт сборки внутри контейнера
│
└── opt/                  # Содержимое пакета (устанавливается в /opt на роутере)
    ├── bin/
    │   ├── frt           # Главная команда (точка входа)
    │   ├── libs/         # Общие библиотеки (main, vpn, check, debug, hosts, tags, …)
    │   └── main/         # Модули: setup, dnsmasq, ipset, ipset_domain, check_vpn, upgrade, update
    └── etc/
        ├── init.d/       # S96frt, S97xray
        ├── ndm/          # Хуки ndm: fs.d, netfilter.d, ifstatechanged.d, iflayerchanged.d, …
        └── conf/         # Конфиги: frt.conf, frt.list, frt.help, dnsmasq.conf, stubby.yml, …
```

## Назначение ключевых каталогов

| Путь | Назначение |
|------|------------|
| **scripts/** | Локальная и CI-сборка .ipk (build-ipk.sh, ci.sh), шаблон postinst. |
| **tests/** | Автотесты без роутера: парсинг списка, генерация dnsmasq, add/del, ошибки. |
| **builder/** | Docker-образы и Jenkins: полная сборка Entware и лёгкий CI. |
| **opt/** | Файлы пакета: при установке копируются в `/opt` (в т.ч. `/opt/apps/frt`, симлинки в `/opt/bin`). |

## Структура на роутере (после установки)

- **Команда:** `/opt/bin/frt` (или `frt` из PATH).
- **Приложение:** `/opt/apps/frt/` — копия `opt/` из пакета.
- **Конфиги:** `/opt/etc/frt.conf`, `/opt/etc/frt.list`, `/opt/etc/dnsmasq.d/frt.dnsmasq`.
- **ipset:** таблица `FRT_LIST`.
- **Сервисы:** init.d `S96frt`, ndm-хуки (100-frt-vpn, 100-dns-local, …).

Подробнее: [Управление роутером](ROUTER.md).
