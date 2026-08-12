/* Этот скрипт готовит базу Cynthia Mini и заполняет её примерами.
   Уже созданные база и таблицы останутся на месте. */
USE master;
GO

IF DB_ID(N'CynthiaMini') IS NULL
    CREATE DATABASE CynthiaMini;
GO

USE CynthiaMini;
GO

IF OBJECT_ID(N'dbo.Companies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Companies (
        Id              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Companies PRIMARY KEY,
        Name            nvarchar(200) NOT NULL,
        TaxNumber       nvarchar(30) NULL,
        IsActive        bit NOT NULL CONSTRAINT DF_Companies_IsActive DEFAULT (1),
        CreatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Companies_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_Companies_Name UNIQUE (Name)
    );
END;
GO

IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        Id              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Users PRIMARY KEY,
        CompanyId       int NOT NULL,
        FullName        nvarchar(160) NOT NULL,
        Email           nvarchar(254) NOT NULL,
        PasswordHash    nvarchar(255) NOT NULL,
        RoleCode        varchar(20) NOT NULL,
        IsActive        bit NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT (1),
        CreatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Users_Companies FOREIGN KEY (CompanyId) REFERENCES dbo.Companies(Id),
        CONSTRAINT UQ_Users_Email UNIQUE (Email),
        CONSTRAINT CK_Users_Role CHECK (RoleCode IN ('ADMIN','MANAGER','RECRUITER'))
    );
END;
GO

IF OBJECT_ID(N'dbo.Vacancies', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Vacancies (
        Id                  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Vacancies PRIMARY KEY,
        CompanyId           int NOT NULL CONSTRAINT DF_Vacancies_Company DEFAULT (1),
        ResponsibleUserId   int NOT NULL,
        Title               nvarchar(200) NOT NULL,
        Department          nvarchar(120) NOT NULL,
        Location            nvarchar(160) NOT NULL,
        SalaryFrom          decimal(12,2) NULL,
        SalaryTo            decimal(12,2) NULL,
        Description         nvarchar(max) NULL,
        Status              varchar(20) NOT NULL CONSTRAINT DF_Vacancies_Status DEFAULT ('OPEN'),
        CreatedAt           datetime2(0) NOT NULL CONSTRAINT DF_Vacancies_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt           datetime2(0) NOT NULL CONSTRAINT DF_Vacancies_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Vacancies_Companies FOREIGN KEY (CompanyId) REFERENCES dbo.Companies(Id),
        CONSTRAINT FK_Vacancies_Users FOREIGN KEY (ResponsibleUserId) REFERENCES dbo.Users(Id),
        CONSTRAINT CK_Vacancies_Status CHECK (Status IN ('DRAFT','OPEN','PAUSED','CLOSED','ARCHIVED')),
        CONSTRAINT CK_Vacancies_Salary CHECK (SalaryFrom IS NULL OR SalaryTo IS NULL OR SalaryFrom <= SalaryTo)
    );
END;
GO

IF OBJECT_ID(N'dbo.Candidates', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Candidates (
        Id              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Candidates PRIMARY KEY,
        FirstName       nvarchar(100) NOT NULL,
        LastName        nvarchar(100) NOT NULL,
        Email           nvarchar(254) NOT NULL,
        Phone           nvarchar(40) NULL,
        City            nvarchar(120) NULL,
        Status          varchar(20) NOT NULL CONSTRAINT DF_Candidates_Status DEFAULT ('NEW'),
        Rating          decimal(3,2) NOT NULL CONSTRAINT DF_Candidates_Rating DEFAULT (0),
        ResumeText      nvarchar(max) NULL,
        CreatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Candidates_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Candidates_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT UQ_Candidates_Email UNIQUE (Email),
        CONSTRAINT CK_Candidates_Status CHECK (Status IN ('NEW','LOOKING','CONSIDERING','EMPLOYED','NOT_LOOKING')),
        CONSTRAINT CK_Candidates_Rating CHECK (Rating BETWEEN 0 AND 5)
    );
END;
GO

IF OBJECT_ID(N'dbo.Applications', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Applications (
        Id              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Applications PRIMARY KEY,
        CandidateId     int NOT NULL,
        VacancyId       int NOT NULL,
        Stage           varchar(20) NOT NULL CONSTRAINT DF_Applications_Stage DEFAULT ('NEW'),
        MatchPercent    tinyint NOT NULL CONSTRAINT DF_Applications_Match DEFAULT (0),
        Notes           nvarchar(1000) NULL,
        CreatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Applications_CreatedAt DEFAULT SYSUTCDATETIME(),
        UpdatedAt       datetime2(0) NOT NULL CONSTRAINT DF_Applications_UpdatedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Applications_Candidates FOREIGN KEY (CandidateId) REFERENCES dbo.Candidates(Id),
        CONSTRAINT FK_Applications_Vacancies FOREIGN KEY (VacancyId) REFERENCES dbo.Vacancies(Id),
        CONSTRAINT UQ_Applications_CandidateVacancy UNIQUE (CandidateId, VacancyId),
        CONSTRAINT CK_Applications_Stage CHECK (Stage IN ('NEW','SCREENING','INTERVIEW','OFFER','HIRED','REJECTED')),
        CONSTRAINT CK_Applications_Match CHECK (MatchPercent BETWEEN 0 AND 100)
    );
END;
GO

IF OBJECT_ID(N'dbo.StatusHistory', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StatusHistory (
        Id                  bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StatusHistory PRIMARY KEY,
        EntityType          varchar(20) NOT NULL,
        EntityId            int NOT NULL,
        OldStatus           varchar(20) NULL,
        NewStatus           varchar(20) NOT NULL,
        ChangedByUserId     int NOT NULL,
        ChangedAt           datetime2(0) NOT NULL CONSTRAINT DF_StatusHistory_ChangedAt DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_StatusHistory_Users FOREIGN KEY (ChangedByUserId) REFERENCES dbo.Users(Id),
        CONSTRAINT CK_StatusHistory_EntityType CHECK (EntityType IN ('VACANCY','CANDIDATE','APPLICATION'))
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Vacancies_Status_CreatedAt')
    CREATE INDEX IX_Vacancies_Status_CreatedAt ON dbo.Vacancies(Status, CreatedAt DESC)
    INCLUDE (Title, Department, Location);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Candidates_Name')
    CREATE INDEX IX_Candidates_Name ON dbo.Candidates(LastName, FirstName);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Applications_Stage_UpdatedAt')
    CREATE INDEX IX_Applications_Stage_UpdatedAt ON dbo.Applications(Stage, UpdatedAt DESC)
    INCLUDE (CandidateId, VacancyId, MatchPercent);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_StatusHistory_Entity')
    CREATE INDEX IX_StatusHistory_Entity ON dbo.StatusHistory(EntityType, EntityId, ChangedAt DESC);
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Companies)
BEGIN
    INSERT dbo.Companies (Name, TaxNumber) VALUES (N'ООО «Вектор»', N'6312345678');
    DECLARE @CompanyId int = SCOPE_IDENTITY();

    INSERT dbo.Users (CompanyId, FullName, Email, PasswordHash, RoleCode)
    VALUES
      (@CompanyId, N'Ольга Воронова', N'admin@example.local', N'DEMO_NOT_USED', 'ADMIN'),
      (@CompanyId, N'Анна Демина', N'anna.demina@example.local', N'DEMO_NOT_USED', 'RECRUITER'),
      (@CompanyId, N'Сергей Лебедев', N'sergey.lebedev@example.local', N'DEMO_NOT_USED', 'RECRUITER'),
      (@CompanyId, N'Ирина Котова', N'irina.kotova@example.local', N'DEMO_NOT_USED', 'MANAGER');

    DECLARE @AnnaId int = (SELECT Id FROM dbo.Users WHERE Email = N'anna.demina@example.local');
    DECLARE @SergeyId int = (SELECT Id FROM dbo.Users WHERE Email = N'sergey.lebedev@example.local');
    DECLARE @ManagerId int = (SELECT Id FROM dbo.Users WHERE Email = N'irina.kotova@example.local');

    INSERT dbo.Vacancies (CompanyId, ResponsibleUserId, Title, Department, Location, SalaryFrom, SalaryTo, Description, Status)
    VALUES
      (@CompanyId, @AnnaId, N'Delphi-разработчик', N'Разработка', N'Самара / гибрид', 120000, 180000, N'Разработка внутренних WEB-сервисов на Delphi и SQL Server.', 'OPEN'),
      (@CompanyId, @AnnaId, N'Системный аналитик', N'ИТ', N'Удалённо', 110000, 160000, N'Сбор требований и моделирование процессов.', 'OPEN'),
      (@CompanyId, @SergeyId, N'HR-менеджер', N'Персонал', N'Самара', 70000, 100000, N'Полный цикл подбора и адаптации.', 'OPEN'),
      (@CompanyId, @SergeyId, N'Frontend-разработчик', N'Разработка', N'Казань / гибрид', 130000, 190000, N'Разработка адаптивных интерфейсов и интеграция с REST API.', 'OPEN'),
      (@CompanyId, @AnnaId, N'Администратор баз данных', N'ИТ', N'Самара', 125000, 175000, N'Поддержка MS SQL Server, резервное копирование и мониторинг.', 'OPEN'),
      (@CompanyId, @ManagerId, N'Менеджер по продажам', N'Продажи', N'Тольятти', 80000, 150000, N'Работа с корпоративными клиентами и CRM.', 'OPEN'),
      (@CompanyId, @ManagerId, N'Специалист технической поддержки', N'Поддержка', N'Удалённо', 65000, 95000, N'Консультации пользователей и регистрация обращений.', 'PAUSED'),
      (@CompanyId, @SergeyId, N'Офис-менеджер', N'Администрация', N'Самара', 55000, 75000, N'Организация работы офиса и документооборота.', 'CLOSED');

    INSERT dbo.Candidates (FirstName, LastName, Email, Phone, City, Status, Rating, ResumeText)
    VALUES
      (N'Иван', N'Петров', N'ivan.petrov@example.local', N'+7 900 100-20-30', N'Самара', 'LOOKING', 4.60, N'Delphi, FireDAC, SQL Server, REST'),
      (N'Мария', N'Соколова', N'maria.sokolova@example.local', N'+7 900 200-30-40', N'Казань', 'CONSIDERING', 4.30, N'Анализ требований, BPMN, SQL'),
      (N'Алексей', N'Орлов', N'alexey.orlov@example.local', N'+7 900 300-40-50', N'Самара', 'LOOKING', 4.10, N'Подбор персонала, интервью, адаптация'),
      (N'Елена', N'Миронова', N'elena.mironova@example.local', N'+7 900 400-50-60', N'Уфа', 'LOOKING', 3.90, N'Delphi, VCL, REST API'),
      (N'Дмитрий', N'Кузнецов', N'dmitry.kuznetsov@example.local', N'+7 900 510-11-22', N'Казань', 'LOOKING', 4.70, N'JavaScript, TypeScript, React, HTML, CSS'),
      (N'Полина', N'Волкова', N'polina.volkova@example.local', N'+7 900 520-22-33', N'Самара', 'CONSIDERING', 4.40, N'MS SQL Server, T-SQL, backup, performance'),
      (N'Никита', N'Фомин', N'nikita.fomin@example.local', N'+7 900 530-33-44', N'Тольятти', 'LOOKING', 4.00, N'B2B продажи, CRM, переговоры'),
      (N'Алина', N'Макарова', N'alina.makarova@example.local', N'+7 900 540-44-55', N'Самара', 'LOOKING', 4.20, N'Поддержка пользователей, Service Desk, SQL'),
      (N'Роман', N'Белов', N'roman.belov@example.local', N'+7 900 550-55-66', N'Пермь', 'CONSIDERING', 3.80, N'System analysis, UML, REST, интеграции'),
      (N'Светлана', N'Егорова', N'svetlana.egorova@example.local', N'+7 900 560-66-77', N'Самара', 'LOOKING', 4.50, N'Рекрутинг, оценка, onboarding'),
      (N'Артём', N'Зайцев', N'artem.zaytsev@example.local', N'+7 900 570-77-88', N'Саратов', 'LOOKING', 3.70, N'Delphi, Object Pascal, PostgreSQL'),
      (N'Виктория', N'Романова', N'victoria.romanova@example.local', N'+7 900 580-88-99', N'Казань', 'CONSIDERING', 4.60, N'Vue, JavaScript, UI/UX'),
      (N'Максим', N'Семенов', N'maxim.semenov@example.local', N'+7 900 590-99-10', N'Самара', 'EMPLOYED', 4.80, N'MS SQL Server, Always On, PowerShell'),
      (N'Дарья', N'Тихонова', N'daria.tikhonova@example.local', N'+7 900 610-10-20', N'Тольятти', 'LOOKING', 3.90, N'Продажи, холодные звонки, отчётность'),
      (N'Кирилл', N'Андреев', N'kirill.andreev@example.local', N'+7 900 620-20-30', N'Самара', 'NOT_LOOKING', 3.60, N'Техническая поддержка, Windows, сети');

    INSERT dbo.Applications (CandidateId, VacancyId, Stage, MatchPercent, Notes)
    SELECT c.Id, v.Id, s.Stage, s.MatchPercent, s.Notes
    FROM (VALUES
      (N'ivan.petrov@example.local', N'Delphi-разработчик', 'INTERVIEW', 91, N'Назначено техническое интервью'),
      (N'maria.sokolova@example.local', N'Системный аналитик', 'SCREENING', 84, N'Проверить опыт моделирования процессов'),
      (N'alexey.orlov@example.local', N'HR-менеджер', 'OFFER', 88, N'Согласование условий'),
      (N'elena.mironova@example.local', N'Delphi-разработчик', 'NEW', 76, N'Новый отклик'),
      (N'dmitry.kuznetsov@example.local', N'Frontend-разработчик', 'INTERVIEW', 93, N'Успешно выполнено тестовое задание'),
      (N'polina.volkova@example.local', N'Администратор баз данных', 'OFFER', 90, N'Подготовлен оффер'),
      (N'nikita.fomin@example.local', N'Менеджер по продажам', 'SCREENING', 79, N'Ожидается телефонное интервью'),
      (N'alina.makarova@example.local', N'Специалист технической поддержки', 'HIRED', 87, N'Кандидат принят'),
      (N'roman.belov@example.local', N'Системный аналитик', 'INTERVIEW', 82, N'Интервью с руководителем'),
      (N'svetlana.egorova@example.local', N'HR-менеджер', 'HIRED', 94, N'Кандидат принята'),
      (N'artem.zaytsev@example.local', N'Delphi-разработчик', 'SCREENING', 72, N'Проверка опыта с WebBroker'),
      (N'victoria.romanova@example.local', N'Frontend-разработчик', 'OFFER', 89, N'Согласование даты выхода'),
      (N'maxim.semenov@example.local', N'Администратор баз данных', 'REJECTED', 86, N'Кандидат выбрал другое предложение'),
      (N'daria.tikhonova@example.local', N'Менеджер по продажам', 'NEW', 74, N'Отклик с карьерного сайта'),
      (N'kirill.andreev@example.local', N'Специалист технической поддержки', 'REJECTED', 68, N'Не готов к смене работы'),
      (N'maria.sokolova@example.local', N'HR-менеджер', 'REJECTED', 55, N'Опыт не соответствует роли'),
      (N'ivan.petrov@example.local', N'Администратор баз данных', 'NEW', 70, N'Есть опыт работы с SQL Server'),
      (N'roman.belov@example.local', N'Delphi-разработчик', 'NEW', 64, N'Рассмотреть после первичного звонка')
    ) s(Email, VacancyTitle, Stage, MatchPercent, Notes)
    JOIN dbo.Candidates c ON c.Email = s.Email
    JOIN dbo.Vacancies v ON v.Title = s.VacancyTitle;

    INSERT dbo.StatusHistory (EntityType, EntityId, OldStatus, NewStatus, ChangedByUserId, ChangedAt)
    SELECT 'APPLICATION', a.Id, NULL, 'NEW', @AnnaId, DATEADD(day, -7, SYSUTCDATETIME())
    FROM dbo.Applications a;

    INSERT dbo.StatusHistory (EntityType, EntityId, OldStatus, NewStatus, ChangedByUserId, ChangedAt)
    SELECT 'APPLICATION', a.Id, 'NEW', a.Stage,
           CASE WHEN a.Id % 2 = 0 THEN @SergeyId ELSE @AnnaId END,
           DATEADD(day, -1, SYSUTCDATETIME())
    FROM dbo.Applications a
    WHERE a.Stage <> 'NEW';
END;
GO

PRINT N'База CynthiaMini готова.';
GO
