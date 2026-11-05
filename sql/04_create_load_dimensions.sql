USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Run 03 first. This loader is for the complete historical snapshot, not changing source records.
IF OBJECT_ID(N'analytics.dim_player', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[dim_player](
	[player_key] [int] IDENTITY(1,1) NOT NULL,
	[player_id] [int] NOT NULL,
	[player_name] [nvarchar](200) NOT NULL,
	[first_name] [nvarchar](200) NULL,
	[last_name] [nvarchar](200) NULL,
	[birth_date] [date] NULL,
	[preferred_foot] [nvarchar](20) NULL,
 CONSTRAINT [PK_dim_player] PRIMARY KEY CLUSTERED 
(
	[player_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dim_player_player_id] UNIQUE NONCLUSTERED 
(
	[player_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'analytics.dim_team', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[dim_team](
	[team_key] [int] IDENTITY(1,1) NOT NULL,
	[team_id] [int] NOT NULL,
	[team_name] [nvarchar](200) NOT NULL,
	[country_id] [int] NULL,
	[team_type] [nvarchar](50) NULL,
	[gender] [nvarchar](20) NULL,
 CONSTRAINT [PK_dim_team] PRIMARY KEY CLUSTERED 
(
	[team_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dim_team_team_id] UNIQUE NONCLUSTERED 
(
	[team_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'analytics.dim_position', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[dim_position](
	[position_key] [int] IDENTITY(1,1) NOT NULL,
	[position_name] [nvarchar](50) NOT NULL,
	[is_midfield] [bit] NOT NULL,
 CONSTRAINT [PK_dim_position] PRIMARY KEY CLUSTERED 
(
	[position_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dim_position_name] UNIQUE NONCLUSTERED 
(
	[position_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'analytics.dim_match', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[dim_match](
	[match_key] [int] IDENTITY(1,1) NOT NULL,
	[match_id] [int] NOT NULL,
	[iteration_id] [int] NOT NULL,
	[home_team_key] [int] NOT NULL,
	[away_team_key] [int] NOT NULL,
	[kickoff_utc] [datetime2](3) NOT NULL,
	[matchday] [smallint] NOT NULL,
	[season_half] [nvarchar](2) NOT NULL,
 CONSTRAINT [PK_dim_match] PRIMARY KEY CLUSTERED 
(
	[match_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_dim_match_match_id] UNIQUE NONCLUSTERED 
(
	[match_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [analytics].[dim_match]  WITH CHECK ADD  CONSTRAINT [FK_dim_match_away_team] FOREIGN KEY([away_team_key])
REFERENCES [analytics].[dim_team] ([team_key])

ALTER TABLE [analytics].[dim_match] CHECK CONSTRAINT [FK_dim_match_away_team]

ALTER TABLE [analytics].[dim_match]  WITH CHECK ADD  CONSTRAINT [FK_dim_match_home_team] FOREIGN KEY([home_team_key])
REFERENCES [analytics].[dim_team] ([team_key])

ALTER TABLE [analytics].[dim_match] CHECK CONSTRAINT [FK_dim_match_home_team]

ALTER TABLE [analytics].[dim_match]  WITH CHECK ADD  CONSTRAINT [CK_dim_match_different_teams] CHECK  (([home_team_key]<>[away_team_key]))

ALTER TABLE [analytics].[dim_match] CHECK CONSTRAINT [CK_dim_match_different_teams]

ALTER TABLE [analytics].[dim_match]  WITH CHECK ADD  CONSTRAINT [CK_dim_match_matchday] CHECK  (([matchday]>=(1) AND [matchday]<=(34)))

ALTER TABLE [analytics].[dim_match] CHECK CONSTRAINT [CK_dim_match_matchday]

ALTER TABLE [analytics].[dim_match]  WITH CHECK ADD  CONSTRAINT [CK_dim_match_season_half] CHECK  (([matchday]<=(17) AND [season_half]=N'H1' OR [matchday]>=(18) AND [season_half]=N'H2'))

ALTER TABLE [analytics].[dim_match] CHECK CONSTRAINT [CK_dim_match_season_half]
END;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
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

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_player;
SELECT player_id, player_name, first_name, last_name, birth_date, preferred_foot INTO #source_player FROM (SELECT player_id,player_name,first_name,last_name,birth_date,preferred_foot FROM staging.players) AS source_rows;
IF EXISTS (SELECT t.player_id, t.player_name, t.first_name, t.last_name, t.birth_date, t.preferred_foot FROM analytics.dim_player t INNER JOIN #source_player s ON t.player_id=s.player_id
           EXCEPT SELECT s.player_id, s.player_name, s.first_name, s.last_name, s.birth_date, s.preferred_foot FROM analytics.dim_player t INNER JOIN #source_player s ON t.player_id=s.player_id)
    THROW 51000, N'analytics.dim_player: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.dim_player (player_id, player_name, first_name, last_name, birth_date, preferred_foot)
SELECT s.player_id, s.player_name, s.first_name, s.last_name, s.birth_date, s.preferred_foot FROM #source_player s
WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_player t WHERE t.player_id=s.player_id);
IF EXISTS (SELECT player_id, player_name, first_name, last_name, birth_date, preferred_foot FROM #source_player EXCEPT SELECT player_id, player_name, first_name, last_name, birth_date, preferred_foot FROM analytics.dim_player)
 OR EXISTS (SELECT player_id, player_name, first_name, last_name, birth_date, preferred_foot FROM analytics.dim_player EXCEPT SELECT player_id, player_name, first_name, last_name, birth_date, preferred_foot FROM #source_player)
    THROW 51000, N'analytics.dim_player: source/target reconciliation failed.', 1;
DROP TABLE #source_player;

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_team;
SELECT team_id, team_name, country_id, team_type, gender INTO #source_team FROM (SELECT team_id,team_name,country_id,team_type,gender FROM staging.teams) AS source_rows;
IF EXISTS (SELECT t.team_id, t.team_name, t.country_id, t.team_type, t.gender FROM analytics.dim_team t INNER JOIN #source_team s ON t.team_id=s.team_id
           EXCEPT SELECT s.team_id, s.team_name, s.country_id, s.team_type, s.gender FROM analytics.dim_team t INNER JOIN #source_team s ON t.team_id=s.team_id)
    THROW 51000, N'analytics.dim_team: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.dim_team (team_id, team_name, country_id, team_type, gender)
SELECT s.team_id, s.team_name, s.country_id, s.team_type, s.gender FROM #source_team s
WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_team t WHERE t.team_id=s.team_id);
IF EXISTS (SELECT team_id, team_name, country_id, team_type, gender FROM #source_team EXCEPT SELECT team_id, team_name, country_id, team_type, gender FROM analytics.dim_team)
 OR EXISTS (SELECT team_id, team_name, country_id, team_type, gender FROM analytics.dim_team EXCEPT SELECT team_id, team_name, country_id, team_type, gender FROM #source_team)
    THROW 51000, N'analytics.dim_team: source/target reconciliation failed.', 1;
DROP TABLE #source_team;

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_position;
SELECT position_name, is_midfield INTO #source_position FROM (SELECT position_name, CAST(CASE WHEN position_name IN (N'CENTRAL_MIDFIELD',N'DEFENSE_MIDFIELD',N'ATTACKING_MIDFIELD') THEN 1 ELSE 0 END AS BIT) AS is_midfield FROM (SELECT position_name FROM staging.player_match_position UNION SELECT position_name FROM staging.events WHERE position_name IS NOT NULL) p) AS source_rows;
IF EXISTS (SELECT t.position_name, t.is_midfield FROM analytics.dim_position t INNER JOIN #source_position s ON t.position_name=s.position_name
           EXCEPT SELECT s.position_name, s.is_midfield FROM analytics.dim_position t INNER JOIN #source_position s ON t.position_name=s.position_name)
    THROW 51000, N'analytics.dim_position: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.dim_position (position_name, is_midfield)
SELECT s.position_name, s.is_midfield FROM #source_position s
WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_position t WHERE t.position_name=s.position_name);
IF EXISTS (SELECT position_name, is_midfield FROM #source_position EXCEPT SELECT position_name, is_midfield FROM analytics.dim_position)
 OR EXISTS (SELECT position_name, is_midfield FROM analytics.dim_position EXCEPT SELECT position_name, is_midfield FROM #source_position)
    THROW 51000, N'analytics.dim_position: source/target reconciliation failed.', 1;
DROP TABLE #source_position;

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_match;
SELECT match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half INTO #source_match FROM (SELECT s.match_id,s.iteration_id,h.team_key AS home_team_key,a.team_key AS away_team_key,s.kickoff_utc,s.matchday,CAST(CASE WHEN s.matchday<=17 THEN N'H1' ELSE N'H2' END AS NVARCHAR(2)) AS season_half FROM staging.matches s JOIN analytics.dim_team h ON s.home_team_id=h.team_id JOIN analytics.dim_team a ON s.away_team_id=a.team_id) AS source_rows;
IF EXISTS (SELECT t.match_id, t.iteration_id, t.home_team_key, t.away_team_key, t.kickoff_utc, t.matchday, t.season_half FROM analytics.dim_match t INNER JOIN #source_match s ON t.match_id=s.match_id
           EXCEPT SELECT s.match_id, s.iteration_id, s.home_team_key, s.away_team_key, s.kickoff_utc, s.matchday, s.season_half FROM analytics.dim_match t INNER JOIN #source_match s ON t.match_id=s.match_id)
    THROW 51000, N'analytics.dim_match: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.dim_match (match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half)
SELECT s.match_id, s.iteration_id, s.home_team_key, s.away_team_key, s.kickoff_utc, s.matchday, s.season_half FROM #source_match s
WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_match t WHERE t.match_id=s.match_id);
IF EXISTS (SELECT match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half FROM #source_match EXCEPT SELECT match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half FROM analytics.dim_match)
 OR EXISTS (SELECT match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half FROM analytics.dim_match EXCEPT SELECT match_id, iteration_id, home_team_key, away_team_key, kickoff_utc, matchday, season_half FROM #source_match)
    THROW 51000, N'analytics.dim_match: source/target reconciliation failed.', 1;
DROP TABLE #source_match;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
