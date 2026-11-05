USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
-- Stops on invalid source keys or missing lookups. NULL event actors are allowed.
IF EXISTS (SELECT 1 FROM staging.players GROUP BY player_id HAVING COUNT_BIG(*)>1)
    THROW 51000, N'players: duplicate source keys', 1;
IF EXISTS (SELECT 1 FROM staging.players WHERE player_id IS NULL OR player_name IS NULL)
    THROW 51000, N'players: required value is NULL', 1;
IF NOT EXISTS (SELECT 1 FROM staging.players) THROW 51000, N'players: staging is empty; import the raw data first.', 1;
IF EXISTS (SELECT 1 FROM staging.teams GROUP BY team_id HAVING COUNT_BIG(*)>1)
    THROW 51000, N'teams: duplicate source keys', 1;
IF EXISTS (SELECT 1 FROM staging.teams WHERE team_id IS NULL OR team_name IS NULL)
    THROW 51000, N'teams: required value is NULL', 1;
IF NOT EXISTS (SELECT 1 FROM staging.teams) THROW 51000, N'teams: staging is empty; import the raw data first.', 1;
IF EXISTS (SELECT 1 FROM staging.matches GROUP BY match_id HAVING COUNT_BIG(*)>1)
    THROW 51000, N'matches: duplicate source keys', 1;
IF EXISTS (SELECT 1 FROM staging.matches WHERE match_id IS NULL OR iteration_id IS NULL OR home_team_id IS NULL OR away_team_id IS NULL OR kickoff_utc IS NULL OR matchday IS NULL)
    THROW 51000, N'matches: required value is NULL', 1;
IF NOT EXISTS (SELECT 1 FROM staging.matches) THROW 51000, N'matches: staging is empty; import the raw data first.', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position GROUP BY match_id,team_id,player_id,position_name HAVING COUNT_BIG(*)>1)
    THROW 51000, N'player_match_position: duplicate source keys', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position WHERE match_id IS NULL OR team_id IS NULL OR player_id IS NULL OR position_name IS NULL OR play_duration_seconds IS NULL OR match_share IS NULL)
    THROW 51000, N'player_match_position: required value is NULL', 1;
IF NOT EXISTS (SELECT 1 FROM staging.player_match_position) THROW 51000, N'player_match_position: staging is empty; import the raw data first.', 1;
IF EXISTS (SELECT 1 FROM staging.events GROUP BY match_id,event_id HAVING COUNT_BIG(*)>1)
    THROW 51000, N'events: duplicate source keys', 1;
IF EXISTS (SELECT 1 FROM staging.events WHERE match_id IS NULL OR event_id IS NULL OR action_type IS NULL)
    THROW 51000, N'events: required value is NULL', 1;
IF NOT EXISTS (SELECT 1 FROM staging.events) THROW 51000, N'events: staging is empty; import the raw data first.', 1;
IF EXISTS (SELECT 1 FROM staging.matches WHERE matchday NOT BETWEEN 1 AND 34 OR home_team_id=away_team_id)
    THROW 51000, N'Invalid matchday or identical teams', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position WHERE play_duration_seconds<0 OR match_share NOT BETWEEN 0 AND 1)
    THROW 51000, N'Invalid playing duration or match share', 1;
IF EXISTS (SELECT 1 FROM staging.matches s WHERE s.home_team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.teams d WHERE d.team_id=s.home_team_id))
    THROW 51000, N'matches: unknown home_team_id', 1;
IF EXISTS (SELECT 1 FROM staging.matches s WHERE s.away_team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.teams d WHERE d.team_id=s.away_team_id))
    THROW 51000, N'matches: unknown away_team_id', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.match_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.matches d WHERE d.match_id=s.match_id))
    THROW 51000, N'player_match_position: unknown match_id', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.teams d WHERE d.team_id=s.team_id))
    THROW 51000, N'player_match_position: unknown team_id', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.player_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.players d WHERE d.player_id=s.player_id))
    THROW 51000, N'player_match_position: unknown player_id', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.match_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.matches d WHERE d.match_id=s.match_id))
    THROW 51000, N'events: unknown match_id', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.teams d WHERE d.team_id=s.team_id))
    THROW 51000, N'events: unknown team_id', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.player_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM staging.players d WHERE d.player_id=s.player_id))
    THROW 51000, N'events: unknown player_id', 1;
SELECT N'players' AS table_name, COUNT_BIG(*) AS actual_rows, CAST(570 AS BIGINT) AS expected_rows FROM staging.players
UNION ALL
SELECT N'teams' AS table_name, COUNT_BIG(*) AS actual_rows, CAST(18 AS BIGINT) AS expected_rows FROM staging.teams
UNION ALL
SELECT N'matches' AS table_name, COUNT_BIG(*) AS actual_rows, CAST(306 AS BIGINT) AS expected_rows FROM staging.matches
UNION ALL
SELECT N'player_match_position' AS table_name, COUNT_BIG(*) AS actual_rows, CAST(10577 AS BIGINT) AS expected_rows FROM staging.player_match_position
UNION ALL
SELECT N'events' AS table_name, COUNT_BIG(*) AS actual_rows, CAST(939200 AS BIGINT) AS expected_rows FROM staging.events;
SELECT action_type, COUNT_BIG(*) AS events_without_player FROM staging.events WHERE player_id IS NULL GROUP BY action_type;
SELECT iteration_id, COUNT(*) AS matches FROM staging.matches GROUP BY iteration_id;
SELECT SUM(play_duration_seconds) AS total_playing_seconds FROM staging.player_match_position;
