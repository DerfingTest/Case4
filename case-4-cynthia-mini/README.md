# Cynthia Mini

Учебный сайт отдела подбора персонала и сильно уменьшенный клон ATS-системы Cynthia. Сайт открывается в браузере, работает через Delphi 10.2 WebBroker и IIS, а данные хранит в Microsoft SQL Server.

## Реализовано

- адаптивная главная страница сайта с показателями;
- список и создание вакансий;
- список и создание кандидатов;
- привязка кандидата к вакансии;
- воронка подбора: новый → скрининг → интервью → оффер → нанят / отказ;
- сохранение истории смены этапов;
- JSON API и параметризованные SQL-запросы FireDAC;
- воспроизводимая схема MS SQL Server с ограничениями, связями, индексами и тестовыми данными.

Учебная версия не включает аутентификацию, загрузку резюме, отправку сообщений, AI-рейтинг и интеграции исходной Cynthia. Интерфейс доступен после публикации DLL в IIS; это не автономный статический макет.

## Структура

```text
CynthiaMini/
├─ CynthiaMini.dpr                 # ISAPI library project
├─ src/WebModuleUnit.pas           # маршрутизация, REST API, FireDAC
├─ src/WebModuleUnit.dfm
├─ www/index.html                  # одностраничный интерфейс
├─ www/styles.css
├─ www/app.js
├─ database/CynthiaMini.sql        # создание БД, таблиц, индексов и данных
├─ database/smoke-test.sql         # контрольные запросы
├─ config.ini.example              # шаблон подключения
└─ web.config                      # пример обработчика IIS
```

## Требования

- Windows 10/11 или Windows Server с IIS;
- Delphi / RAD Studio 10.2 Tokyo;
- Microsoft SQL Server 2016+ и SQL Server Management Studio;
- Microsoft ODBC Driver for SQL Server или SQL Server Native Client, доступный FireDAC;
- включённая роль IIS `ISAPI Extensions`.

Разрядность DLL, пула приложений IIS и драйвера SQL Server должна совпадать.

## 1. Создание базы данных

1. Подключитесь к SQL Server через SSMS под учётной записью с правом `CREATE DATABASE`.
2. Откройте `database/CynthiaMini.sql` и выполните весь скрипт.
3. Выполните `database/smoke-test.sql`. В демонстрационном наборе создаются 8 вакансий, 15 кандидатов и 18 откликов на разных этапах.

Скрипт не удаляет существующую БД и повторно не добавляет демонстрационный набор, если в `Companies` уже есть данные.

## 2. Настройка проекта Delphi

1. Откройте `CynthiaMini.dpr` в Delphi 10.2.
2. Выберите `Release` и целевую платформу, совпадающую с пулом IIS (обычно Win64).
3. Убедитесь, что FireDAC MSSQL включён в сборку.
4. Выполните Build. Результатом должна быть `CynthiaMini.dll`.

Если IDE создаст `.dproj`, его можно добавить в репозиторий. Исходный `.dpr` самодостаточен для импорта проекта в IDE.

## 3. Публикация в IIS

1. Создайте `C:\inetpub\CynthiaMini`.
2. Скопируйте туда `CynthiaMini.dll`, папку `www`, `web.config` и `config.ini.example`.
3. Переименуйте `config.ini.example` в `config.ini` и настройте подключение.
4. В Server Manager включите Web Server (IIS) → Application Development → ISAPI Extensions.
5. Создайте отдельный пул приложений без Managed Runtime. Установите разрядность в соответствии с DLL.
6. Создайте сайт или приложение с физическим путём `C:\inetpub\CynthiaMini`.
7. В `ISAPI and CGI Restrictions` разрешите полный путь к `CynthiaMini.dll`.
8. Проверьте `scriptProcessor` в `web.config`: путь должен совпадать с фактическим.
9. Дайте учётной записи пула право чтения папки и доступ к БД, если используется Windows Authentication.
10. Откройте корень сайта. Для диагностики проверьте `/api/dashboard`.

Пример SQL-аутентификации:

```ini
[database]
Server=localhost\SQLEXPRESS
Database=CynthiaMini
OSAuthent=False
UserName=cynthia_app
Password=replace_me
```

Не публикуйте `config.ini` в Git: файл уже исключён через `.gitignore`.

## JSON API

| Метод | Маршрут | Назначение |
|---|---|---|
| GET | `/api/dashboard` | Сводные показатели |
| GET/POST | `/api/vacancies` | Список / создание вакансии |
| GET/POST | `/api/candidates` | Список / создание кандидата |
| GET/POST | `/api/applications` | Воронка / новый отклик |
| PUT | `/api/applications/{id}/stage` | Смена этапа подбора |

Пример:

```powershell
Invoke-RestMethod http://localhost/CynthiaMini/api/candidates -Method Post `
  -ContentType 'application/json' `
  -Body '{"firstName":"Павел","lastName":"Иванов","email":"p.ivanov@example.local","phone":"+7 900 000-00-00","city":"Самара"}'
```

## Создание GitHub-репозитория

Команды выполняются из папки `CynthiaMini` после проверки проекта:

```powershell
git init
git add .
git commit -m "Initial Cynthia Mini Delphi WebBroker application"
git branch -M main
git remote add origin https://github.com/<user>/cynthia-mini-delphi.git
git push -u origin main
```

Сам репозиторий автоматически не создавался: для публикации потребуется выбранный аккаунт GitHub и его авторизация.

## Ограничения и развитие

Для промышленного применения следует добавить JWT/Windows-аутентификацию, разграничение ролей, CSRF/CORS-политику, журнал аудита со старым статусом, транзакции для связанных изменений, загрузку файлов во внешнее хранилище, пагинацию, тесты API, защищённое хранение секретов и HTTPS.
