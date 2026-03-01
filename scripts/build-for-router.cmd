@echo off
chcp 65001 >nul
echo Сборка FRT .ipk в Docker для Keenetic...
echo.
docker-compose build ci
if errorlevel 1 (
  echo Ошибка сборки образа.
  exit /b 1
)
docker-compose run --rm ci
if errorlevel 1 (
  echo Ошибка сборки пакета или тестов.
  exit /b 1
)
echo.
echo Готово. Пакет: output\frt_*.ipk
echo Скопируйте его на Keenetic и выполните: opkg install /path/to/frt_*.ipk
dir /b output\frt_*.ipk 2>nul
