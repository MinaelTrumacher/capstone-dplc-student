-- ============================================================
-- Script d'initialisation de la base de données
-- Coupe du Monde 2026
-- Ce script est idempotent : il peut être exécuté plusieurs
-- fois sans erreur et sans perte de données existantes.
-- ============================================================

-- Table des équipes
CREATE TABLE IF NOT EXISTS teams (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    group_letter CHAR(1) NOT NULL,
    country_code CHAR(3) NOT NULL
);

-- Table des matchs
CREATE TABLE IF NOT EXISTS matches (
    id SERIAL PRIMARY KEY,
    team_home_id INTEGER REFERENCES teams(id),
    team_away_id INTEGER REFERENCES teams(id),
    score_home INTEGER DEFAULT 0,
    score_away INTEGER DEFAULT 0,
    stage VARCHAR(50) NOT NULL,
    match_date DATE NOT NULL,
    played_at TIMESTAMP DEFAULT NOW()
);

-- Table des votes (pronostics)
CREATE TABLE IF NOT EXISTS votes (
    id SERIAL PRIMARY KEY,
    team_id INTEGER REFERENCES teams(id) NOT NULL,
    voted_at TIMESTAMP DEFAULT NOW()
);

-- ============================================================
-- Insertion des 48 équipes officielles de la Coupe du Monde 2026
-- Groupes A à L (4 équipes par groupe)
-- ============================================================

INSERT INTO teams (name, group_letter, country_code) VALUES
-- Groupe A
('Mexico', 'A', 'MEX'),
('South Africa', 'A', 'RSA'),
('South Korea', 'A', 'KOR'),
('Czech Republic', 'A', 'CZE'),
-- Groupe B
('Canada', 'B', 'CAN'),
('Bosnia and Herzegovina', 'B', 'BIH'),
('Qatar', 'B', 'QAT'),
('Switzerland', 'B', 'SUI'),
-- Groupe C
('Brazil', 'C', 'BRA'),
('Morocco', 'C', 'MAR'),
('Haiti', 'C', 'HAI'),
('Scotland', 'C', 'SCO'),
-- Groupe D
('United States', 'D', 'USA'),
('Paraguay', 'D', 'PAR'),
('Australia', 'D', 'AUS'),
('Turkey', 'D', 'TUR'),
-- Groupe E
('Germany', 'E', 'GER'),
('Ivory Coast', 'E', 'CIV'),
('Ecuador', 'E', 'ECU'),
('Curaçao', 'E', 'CUW'),
-- Groupe F
('Netherlands', 'F', 'NED'),
('Japan', 'F', 'JPN'),
('Sweden', 'F', 'SWE'),
('Tunisia', 'F', 'TUN'),
-- Groupe G
('Belgium', 'G', 'BEL'),
('Egypt', 'G', 'EGY'),
('Iran', 'G', 'IRN'),
('New Zealand', 'G', 'NZL'),
-- Groupe H
('Spain', 'H', 'ESP'),
('Cape Verde', 'H', 'CPV'),
('Saudi Arabia', 'H', 'KSA'),
('Uruguay', 'H', 'URU'),
-- Groupe I
('France', 'I', 'FRA'),
('Senegal', 'I', 'SEN'),
('Iraq', 'I', 'IRQ'),
('Norway', 'I', 'NOR'),
-- Groupe J
('Argentina', 'J', 'ARG'),
('Algeria', 'J', 'ALG'),
('Austria', 'J', 'AUT'),
('Jordan', 'J', 'JOR'),
-- Groupe K
('Portugal', 'K', 'POR'),
('DR Congo', 'K', 'COD'),
('Uzbekistan', 'K', 'UZB'),
('Colombia', 'K', 'COL'),
-- Groupe L
('England', 'L', 'ENG'),
('Croatia', 'L', 'CRO'),
('Ghana', 'L', 'GHA'),
('Panama', 'L', 'PAN')
ON CONFLICT (name) DO NOTHING;

-- ============================================================
-- Insertion des résultats réels de la phase de groupes
-- Coupe du Monde 2026 (matchdays 1 et 2)
-- ============================================================

INSERT INTO matches (team_home_id, team_away_id, score_home, score_away, stage, match_date) VALUES
-- Groupe A (matchday 1 : 11 juin, matchday 2 : 18-19 juin)
((SELECT id FROM teams WHERE name = 'Mexico'), (SELECT id FROM teams WHERE name = 'South Africa'), 2, 0, 'Group Stage', '2026-06-11'),
((SELECT id FROM teams WHERE name = 'South Korea'), (SELECT id FROM teams WHERE name = 'Czech Republic'), 2, 1, 'Group Stage', '2026-06-11'),
((SELECT id FROM teams WHERE name = 'Mexico'), (SELECT id FROM teams WHERE name = 'South Korea'), 1, 0, 'Group Stage', '2026-06-19'),
((SELECT id FROM teams WHERE name = 'Czech Republic'), (SELECT id FROM teams WHERE name = 'South Africa'), 1, 1, 'Group Stage', '2026-06-19'),
-- Groupe B (matchday 1 : 12-13 juin, matchday 2 : 18-19 juin)
((SELECT id FROM teams WHERE name = 'Canada'), (SELECT id FROM teams WHERE name = 'Bosnia and Herzegovina'), 1, 1, 'Group Stage', '2026-06-12'),
((SELECT id FROM teams WHERE name = 'Qatar'), (SELECT id FROM teams WHERE name = 'Switzerland'), 1, 1, 'Group Stage', '2026-06-13'),
((SELECT id FROM teams WHERE name = 'Switzerland'), (SELECT id FROM teams WHERE name = 'Bosnia and Herzegovina'), 4, 1, 'Group Stage', '2026-06-18'),
((SELECT id FROM teams WHERE name = 'Canada'), (SELECT id FROM teams WHERE name = 'Qatar'), 6, 0, 'Group Stage', '2026-06-19'),
-- Groupe C (matchday 1 : 13-14 juin, matchday 2 : 19-20 juin)
((SELECT id FROM teams WHERE name = 'Brazil'), (SELECT id FROM teams WHERE name = 'Morocco'), 1, 1, 'Group Stage', '2026-06-13'),
((SELECT id FROM teams WHERE name = 'Scotland'), (SELECT id FROM teams WHERE name = 'Haiti'), 1, 0, 'Group Stage', '2026-06-14'),
((SELECT id FROM teams WHERE name = 'Brazil'), (SELECT id FROM teams WHERE name = 'Haiti'), 3, 0, 'Group Stage', '2026-06-20'),
((SELECT id FROM teams WHERE name = 'Morocco'), (SELECT id FROM teams WHERE name = 'Scotland'), 1, 0, 'Group Stage', '2026-06-20'),
-- Groupe D (matchday 1 : 12-14 juin, matchday 2 : 19 juin)
((SELECT id FROM teams WHERE name = 'United States'), (SELECT id FROM teams WHERE name = 'Paraguay'), 4, 1, 'Group Stage', '2026-06-12'),
((SELECT id FROM teams WHERE name = 'Australia'), (SELECT id FROM teams WHERE name = 'Turkey'), 2, 0, 'Group Stage', '2026-06-14'),
((SELECT id FROM teams WHERE name = 'United States'), (SELECT id FROM teams WHERE name = 'Australia'), 2, 0, 'Group Stage', '2026-06-19'),
-- Groupe E (matchday 1 : 14 juin)
((SELECT id FROM teams WHERE name = 'Germany'), (SELECT id FROM teams WHERE name = 'Curaçao'), 7, 1, 'Group Stage', '2026-06-14'),
((SELECT id FROM teams WHERE name = 'Ivory Coast'), (SELECT id FROM teams WHERE name = 'Ecuador'), 1, 0, 'Group Stage', '2026-06-14'),
-- Groupe F (matchday 1 : 14-15 juin, matchday 2 : 20 juin)
((SELECT id FROM teams WHERE name = 'Netherlands'), (SELECT id FROM teams WHERE name = 'Japan'), 2, 2, 'Group Stage', '2026-06-14'),
((SELECT id FROM teams WHERE name = 'Sweden'), (SELECT id FROM teams WHERE name = 'Tunisia'), 5, 1, 'Group Stage', '2026-06-14'),
((SELECT id FROM teams WHERE name = 'Netherlands'), (SELECT id FROM teams WHERE name = 'Sweden'), 5, 1, 'Group Stage', '2026-06-20'),
((SELECT id FROM teams WHERE name = 'Japan'), (SELECT id FROM teams WHERE name = 'Tunisia'), 4, 0, 'Group Stage', '2026-06-20'),
-- Groupe G (matchday 1 : 15 juin)
((SELECT id FROM teams WHERE name = 'Belgium'), (SELECT id FROM teams WHERE name = 'Egypt'), 1, 1, 'Group Stage', '2026-06-15'),
-- Groupe H (matchday 1 : 15 juin)
((SELECT id FROM teams WHERE name = 'Spain'), (SELECT id FROM teams WHERE name = 'Cape Verde'), 0, 0, 'Group Stage', '2026-06-15'),
((SELECT id FROM teams WHERE name = 'Saudi Arabia'), (SELECT id FROM teams WHERE name = 'Uruguay'), 1, 1, 'Group Stage', '2026-06-15'),
-- Groupe I (matchday 1 : 16 juin, matchday 2 : 22 juin)
((SELECT id FROM teams WHERE name = 'France'), (SELECT id FROM teams WHERE name = 'Senegal'), 3, 1, 'Group Stage', '2026-06-16'),
((SELECT id FROM teams WHERE name = 'Norway'), (SELECT id FROM teams WHERE name = 'Iraq'), 4, 1, 'Group Stage', '2026-06-16'),
((SELECT id FROM teams WHERE name = 'France'), (SELECT id FROM teams WHERE name = 'Iraq'), 3, 0, 'Group Stage', '2026-06-22'),
((SELECT id FROM teams WHERE name = 'Norway'), (SELECT id FROM teams WHERE name = 'Senegal'), 3, 2, 'Group Stage', '2026-06-22'),
-- Groupe J (matchday 1 : 16-17 juin, matchday 2 : 22 juin)
((SELECT id FROM teams WHERE name = 'Argentina'), (SELECT id FROM teams WHERE name = 'Algeria'), 3, 0, 'Group Stage', '2026-06-16'),
((SELECT id FROM teams WHERE name = 'Austria'), (SELECT id FROM teams WHERE name = 'Jordan'), 3, 1, 'Group Stage', '2026-06-17'),
((SELECT id FROM teams WHERE name = 'Argentina'), (SELECT id FROM teams WHERE name = 'Austria'), 2, 0, 'Group Stage', '2026-06-22'),
-- Groupe K (matchday 1 : 17 juin)
((SELECT id FROM teams WHERE name = 'Colombia'), (SELECT id FROM teams WHERE name = 'Uzbekistan'), 3, 1, 'Group Stage', '2026-06-17'),
-- Groupe L (matchday 1 : 17 juin)
((SELECT id FROM teams WHERE name = 'England'), (SELECT id FROM teams WHERE name = 'Croatia'), 4, 2, 'Group Stage', '2026-06-17'),
((SELECT id FROM teams WHERE name = 'Ghana'), (SELECT id FROM teams WHERE name = 'Panama'), 1, 0, 'Group Stage', '2026-06-17')
ON CONFLICT DO NOTHING;
