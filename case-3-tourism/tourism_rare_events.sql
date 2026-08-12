-- Учебная база для агентства, которое организует поездки к редким природным явлениям.
-- Скрипт рассчитан на MySQL 8.0.16 и более новые версии.

CREATE DATABASE IF NOT EXISTS tourism_rare_events
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE tourism_rare_events;

-- Здесь собраны места, куда можно отправиться, и явления, которые там наблюдают.
CREATE TABLE IF NOT EXISTS destinations (
    destination_id      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    destination_name    VARCHAR(120) NOT NULL,
    country_name        VARCHAR(80) NOT NULL,
    rare_phenomenon     VARCHAR(160) NOT NULL,
    best_season         VARCHAR(80) NOT NULL,
    latitude            DECIMAL(9,6) NULL,
    longitude           DECIMAL(9,6) NULL,
    risk_level          ENUM('LOW', 'MEDIUM', 'HIGH') NOT NULL DEFAULT 'LOW',
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (destination_id),
    UNIQUE KEY uq_destinations_name_country (destination_name, country_name),
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;

-- Здесь описаны форматы путешествий: их сложность, длительность и размер группы.
CREATE TABLE IF NOT EXISTS tour_themes (
    theme_id            SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    theme_name          VARCHAR(100) NOT NULL,
    description         VARCHAR(500) NOT NULL,
    difficulty_level    ENUM('EASY', 'MODERATE', 'EXTREME') NOT NULL,
    duration_days       TINYINT UNSIGNED NOT NULL,
    minimum_age         TINYINT UNSIGNED NOT NULL DEFAULT 12,
    max_group_size      TINYINT UNSIGNED NOT NULL,
    PRIMARY KEY (theme_id),
    UNIQUE KEY uq_tour_themes_name (theme_name),
    CHECK (duration_days BETWEEN 1 AND 30),
    CHECK (minimum_age BETWEEN 6 AND 80),
    CHECK (max_group_size BETWEEN 1 AND 40)
) ENGINE=InnoDB;

-- В этой таблице видно, что входит в каждый пакет услуг и сколько он стоит.
CREATE TABLE IF NOT EXISTS service_packages (
    service_package_id  SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    package_name        VARCHAR(100) NOT NULL,
    included_services   VARCHAR(600) NOT NULL,
    insurance_level     ENUM('BASIC', 'EXTENDED', 'EXPEDITION') NOT NULL,
    price_per_person    DECIMAL(10,2) NOT NULL,
    equipment_included  BOOLEAN NOT NULL DEFAULT FALSE,
    transfer_included   BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (service_package_id),
    UNIQUE KEY uq_service_packages_name (package_name),
    CHECK (price_per_person >= 0)
) ENGINE=InnoDB;

-- Контактные данные путешественников, для которых оформляются поездки.
CREATE TABLE IF NOT EXISTS travelers (
    traveler_id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    full_name           VARCHAR(150) NOT NULL,
    birth_date          DATE NOT NULL,
    phone               VARCHAR(30) NOT NULL,
    email               VARCHAR(160) NOT NULL,
    passport_number     VARCHAR(30) NOT NULL,
    emergency_contact   VARCHAR(160) NULL,
    loyalty_level       ENUM('EXPLORER', 'PATHFINDER', 'LEGEND') NOT NULL DEFAULT 'EXPLORER',
    PRIMARY KEY (traveler_id),
    UNIQUE KEY uq_travelers_email (email),
    UNIQUE KEY uq_travelers_passport (passport_number)
) ENGINE=InnoDB;

-- Каждый заказ связывает клиента, направление, формат тура и выбранный пакет услуг.
CREATE TABLE IF NOT EXISTS tour_orders (
    order_id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    booking_code            CHAR(10) NOT NULL,
    traveler_id             INT UNSIGNED NOT NULL,
    destination_id          INT UNSIGNED NOT NULL,
    theme_id                SMALLINT UNSIGNED NOT NULL,
    service_package_id      SMALLINT UNSIGNED NOT NULL,
    order_date              DATE NOT NULL,
    start_date              DATE NOT NULL,
    participants_count      TINYINT UNSIGNED NOT NULL DEFAULT 1,
    tour_price_per_person   DECIMAL(10,2) NOT NULL,
    service_price_per_person DECIMAL(10,2) NOT NULL,
    discount_percent        DECIMAL(5,2) NOT NULL DEFAULT 0,
    order_status            ENUM('NEW', 'CONFIRMED', 'PAID', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'NEW',
    special_wishes          VARCHAR(500) NULL,
    total_amount            DECIMAL(12,2)
        GENERATED ALWAYS AS (
            ROUND(
                (tour_price_per_person + service_price_per_person)
                * participants_count
                * (1 - discount_percent / 100),
                2
            )
        ) STORED,
    PRIMARY KEY (order_id),
    UNIQUE KEY uq_tour_orders_booking_code (booking_code),
    KEY ix_tour_orders_start_status (start_date, order_status),
    KEY ix_tour_orders_traveler (traveler_id, order_date),
    KEY ix_tour_orders_destination (destination_id, start_date),
    CONSTRAINT fk_orders_traveler
        FOREIGN KEY (traveler_id) REFERENCES travelers (traveler_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orders_destination
        FOREIGN KEY (destination_id) REFERENCES destinations (destination_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orders_theme
        FOREIGN KEY (theme_id) REFERENCES tour_themes (theme_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_orders_service_package
        FOREIGN KEY (service_package_id) REFERENCES service_packages (service_package_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (start_date > order_date),
    CHECK (participants_count BETWEEN 1 AND 40),
    CHECK (tour_price_per_person >= 0),
    CHECK (service_price_per_person >= 0),
    CHECK (discount_percent BETWEEN 0 AND 40)
) ENGINE=InnoDB;

-- Добавляем данные, на которых можно сразу проверить работу справочников.
INSERT IGNORE INTO destinations
    (destination_id, destination_name, country_name, rare_phenomenon, best_season,
     latitude, longitude, risk_level, is_active)
VALUES
    (1, 'Тромсё', 'Норвегия', 'Северное сияние над фьордами', 'октябрь–март', 69.649205, 18.955324, 'MEDIUM', TRUE),
    (2, 'Вади-Рам', 'Иордания', 'Пустынное небо без светового загрязнения', 'март–май', 29.576359, 35.419480, 'MEDIUM', TRUE),
    (3, 'Остров Вулкано', 'Италия', 'Фумаролы и вулканические ландшафты', 'апрель–июнь', 38.404299, 14.962998, 'HIGH', TRUE),
    (4, 'Москито-Бей', 'Пуэрто-Рико', 'Биолюминесцентная бухта', 'круглый год', 18.097944, -65.444234, 'LOW', TRUE),
    (5, 'Алтайский биосферный заповедник', 'Россия', 'Звёздное небо и высокогорные озёра', 'июль–сентябрь', 51.079030, 87.724700, 'MEDIUM', TRUE),
    (6, 'Салар-де-Уюни', 'Боливия', 'Зеркальная поверхность солончака', 'январь–март', -20.133777, -67.489134, 'HIGH', TRUE),
    (7, 'Фарерские острова', 'Дания', 'Полное солнечное затмение и океанские скалы', 'по календарю затмений', 62.007864, -6.790982, 'MEDIUM', TRUE),
    (8, 'Каппадокия', 'Турция', 'Воздушные шары над каменными долинами', 'апрель–октябрь', 38.643057, 34.828983, 'LOW', TRUE);

INSERT IGNORE INTO tour_themes
    (theme_id, theme_name, description, difficulty_level, duration_days, minimum_age, max_group_size)
VALUES
    (1, 'Охота за авророй', 'Ночные выезды к точкам наблюдения северного сияния.', 'MODERATE', 6, 12, 12),
    (2, 'Экспедиция к затмению', 'Путешествие, рассчитанное по календарю солнечных затмений.', 'MODERATE', 5, 10, 20),
    (3, 'Живая планета', 'Наблюдение вулканов, гейзеров и геотермальных зон.', 'EXTREME', 8, 18, 8),
    (4, 'Светящийся океан', 'Ночные каяк-маршруты по биолюминесцентным бухтам.', 'MODERATE', 4, 14, 10),
    (5, 'Тёмное небо', 'Астрономический тур с телескопами и лекциями.', 'EASY', 5, 8, 18),
    (6, 'Зеркало горизонта', 'Фотоэкспедиция по отражающим природным ландшафтам.', 'MODERATE', 7, 12, 10);

INSERT IGNORE INTO service_packages
    (service_package_id, package_name, included_services, insurance_level,
     price_per_person, equipment_included, transfer_included)
VALUES
    (1, 'Лёгкий старт', 'Групповой трансфер, городской отель, базовая страховка', 'BASIC', 18000.00, FALSE, TRUE),
    (2, 'Фотоохотник', 'Трансфер, штатив, фотогид, запасные аккумуляторы, страховка', 'EXTENDED', 39500.00, TRUE, TRUE),
    (3, 'Научная смена', 'Лекции эксперта, приборы наблюдения, полевой журнал, трансфер', 'EXTENDED', 52000.00, TRUE, TRUE),
    (4, 'Экспедиция 360', 'Все трансферы, специальное снаряжение, спутниковая связь, расширенная страховка', 'EXPEDITION', 89000.00, TRUE, TRUE),
    (5, 'Свободный маршрут', 'Консультация координатора и базовая страховка без трансфера', 'BASIC', 9500.00, FALSE, FALSE);

INSERT IGNORE INTO travelers
    (traveler_id, full_name, birth_date, phone, email, passport_number,
     emergency_contact, loyalty_level)
VALUES
    (1, 'Анна Ветрова', '1991-04-18', '+7 900 111-20-30', 'anna.vetrova@example.com', '71 4455667', 'Илья Ветров +7 900 201-10-10', 'PATHFINDER'),
    (2, 'Михаил Северин', '1986-11-02', '+7 900 112-20-30', 'm.severin@example.com', '72 1100234', 'Ольга Северина +7 900 202-20-20', 'LEGEND'),
    (3, 'Лейла Каримова', '1997-08-21', '+7 900 113-20-30', 'leyla.k@example.com', '80 3344556', 'Руслан Каримов +7 900 203-30-30', 'EXPLORER'),
    (4, 'Павел Озеров', '1989-01-30', '+7 900 114-20-30', 'pavel.ozerov@example.com', '63 7788990', 'Наталья Озерова +7 900 204-40-40', 'PATHFINDER'),
    (5, 'Софья Лунная', '1994-06-12', '+7 900 115-20-30', 'sofia.lunnaya@example.com', '45 9011223', 'Андрей Лунин +7 900 205-50-50', 'EXPLORER'),
    (6, 'Тимур Сафин', '1983-09-07', '+7 900 116-20-30', 'timur.safin@example.com', '92 1234789', 'Эльмира Сафина +7 900 206-60-60', 'LEGEND'),
    (7, 'Ева Миронова', '2000-03-16', '+7 900 117-20-30', 'eva.mironova@example.com', '46 6655443', 'Мария Миронова +7 900 207-70-70', 'EXPLORER'),
    (8, 'Денис Громов', '1992-12-25', '+7 900 118-20-30', 'denis.gromov@example.com', '73 2200114', 'Олег Громов +7 900 208-80-80', 'PATHFINDER'),
    (9, 'Арина Сокол', '1988-05-09', '+7 900 119-20-30', 'arina.sokol@example.com', '40 7700881', 'Вера Сокол +7 900 209-90-90', 'PATHFINDER'),
    (10, 'Глеб Романов', '1996-10-14', '+7 900 120-20-30', 'gleb.romanov@example.com', '50 1010101', 'Ирина Романова +7 900 210-10-10', 'EXPLORER');

-- Добавляем несколько заказов, чтобы проверить связи, расчёты и отчёты.
INSERT IGNORE INTO tour_orders
    (order_id, booking_code, traveler_id, destination_id, theme_id,
     service_package_id, order_date, start_date, participants_count,
     tour_price_per_person, service_price_per_person, discount_percent,
     order_status, special_wishes)
VALUES
    (1, 'AUR26T001', 1, 1, 1, 2, '2026-01-15', '2026-11-10', 2, 168000.00, 39500.00, 7.00, 'PAID', 'Нужен штатив для съёмки северного сияния'),
    (2, 'SKY26W002', 2, 2, 5, 3, '2026-02-02', '2026-10-18', 1, 142000.00, 52000.00, 10.00, 'CONFIRMED', 'Телескоп с адаптером для смартфона'),
    (3, 'VOL26I003', 3, 3, 3, 4, '2026-02-21', '2026-09-05', 1, 215000.00, 89000.00, 0.00, 'PAID', 'Вегетарианское питание'),
    (4, 'BIO26P004', 4, 4, 4, 1, '2026-03-04', '2026-12-01', 2, 128000.00, 18000.00, 5.00, 'CONFIRMED', 'Два одноместных номера'),
    (5, 'ALT26R005', 5, 5, 5, 3, '2026-03-22', '2026-08-12', 1, 96000.00, 52000.00, 0.00, 'PAID', 'Интересуют лекции по астрофотографии'),
    (6, 'UYU27B006', 6, 6, 6, 4, '2026-04-10', '2027-02-14', 2, 238000.00, 89000.00, 12.00, 'CONFIRMED', 'Съёмка таймлапса на рассвете'),
    (7, 'ECL27F007', 7, 7, 2, 2, '2026-04-28', '2027-08-01', 1, 176000.00, 39500.00, 0.00, 'NEW', 'Защитные фильтры для камеры'),
    (8, 'CAP26T008', 8, 8, 6, 1, '2026-05-09', '2026-09-20', 3, 104000.00, 18000.00, 5.00, 'PAID', 'Полёт на воздушном шаре утром'),
    (9, 'AUR26T009', 9, 1, 1, 4, '2026-05-30', '2026-12-12', 1, 171000.00, 89000.00, 10.00, 'CONFIRMED', 'Тёплая экипировка размера S'),
    (10, 'SKY26W010', 10, 2, 5, 5, '2026-06-11', '2026-11-02', 2, 138000.00, 9500.00, 0.00, 'NEW', 'Самостоятельный трансфер'),
    (11, 'BIO26P011', 1, 4, 4, 2, '2026-06-24', '2027-01-15', 2, 132000.00, 39500.00, 7.00, 'CONFIRMED', 'Герметичный чехол для фотокамеры'),
    (12, 'ALT26R012', 4, 5, 5, 4, '2026-07-03', '2026-07-08', 1, 99000.00, 89000.00, 5.00, 'COMPLETED', 'Спутниковая связь на всём маршруте'),
    (13, 'VOL26I013', 6, 3, 3, 4, '2026-07-18', '2026-10-06', 1, 218000.00, 89000.00, 15.00, 'CANCELLED', 'Защитная маска для фумарол'),
    (14, 'CAP27T014', 2, 8, 6, 3, '2026-08-01', '2027-05-12', 2, 110000.00, 52000.00, 10.00, 'PAID', 'Фотогид на рассвете');

-- Собираем связанные данные в один удобный список заказов.
CREATE OR REPLACE VIEW v_tour_orders AS
SELECT
    o.booking_code,
    o.order_date,
    o.start_date,
    t.full_name AS traveler,
    d.destination_name,
    d.country_name,
    d.rare_phenomenon,
    th.theme_name,
    sp.package_name,
    o.participants_count,
    o.order_status,
    o.total_amount
FROM tour_orders AS o
JOIN travelers AS t ON t.traveler_id = o.traveler_id
JOIN destinations AS d ON d.destination_id = o.destination_id
JOIN tour_themes AS th ON th.theme_id = o.theme_id
JOIN service_packages AS sp ON sp.service_package_id = o.service_package_id;

-- Эти запросы помогают быстро убедиться, что данные загрузились правильно.
SELECT * FROM v_tour_orders ORDER BY start_date;

SELECT
    d.destination_name,
    COUNT(*) AS orders_count,
    SUM(o.total_amount) AS expected_revenue
FROM tour_orders AS o
JOIN destinations AS d ON d.destination_id = o.destination_id
WHERE o.order_status <> 'CANCELLED'
GROUP BY d.destination_id, d.destination_name
ORDER BY expected_revenue DESC;

SELECT
    order_status,
    COUNT(*) AS orders_count,
    SUM(total_amount) AS amount
FROM tour_orders
GROUP BY order_status
ORDER BY orders_count DESC;
