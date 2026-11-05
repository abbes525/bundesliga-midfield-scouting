USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Run 03 and 04 first. Preserves NULL event actors and existing surrogate keys.
IF OBJECT_ID(N'analytics.fact_player_match_position', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[fact_player_match_position](
	[playing_time_key] [int] IDENTITY(1,1) NOT NULL,
	[match_key] [int] NOT NULL,
	[team_key] [int] NOT NULL,
	[player_key] [int] NOT NULL,
	[position_key] [int] NOT NULL,
	[play_duration_seconds] [decimal](18, 6) NOT NULL,
	[match_share] [decimal](12, 10) NOT NULL,
 CONSTRAINT [PK_fact_player_match_position] PRIMARY KEY CLUSTERED 
(
	[playing_time_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_fact_player_match_position] UNIQUE NONCLUSTERED 
(
	[match_key] ASC,
	[team_key] ASC,
	[player_key] ASC,
	[position_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [FK_playing_time_match] FOREIGN KEY([match_key])
REFERENCES [analytics].[dim_match] ([match_key])

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [FK_playing_time_match]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [FK_playing_time_player] FOREIGN KEY([player_key])
REFERENCES [analytics].[dim_player] ([player_key])

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [FK_playing_time_player]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [FK_playing_time_position] FOREIGN KEY([position_key])
REFERENCES [analytics].[dim_position] ([position_key])

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [FK_playing_time_position]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [FK_playing_time_team] FOREIGN KEY([team_key])
REFERENCES [analytics].[dim_team] ([team_key])

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [FK_playing_time_team]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [CK_playing_time_match_share] CHECK  (([match_share]>=(0) AND [match_share]<=(1)))

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [CK_playing_time_match_share]

ALTER TABLE [analytics].[fact_player_match_position]  WITH CHECK ADD  CONSTRAINT [CK_playing_time_nonnegative] CHECK  (([play_duration_seconds]>=(0)))

ALTER TABLE [analytics].[fact_player_match_position] CHECK CONSTRAINT [CK_playing_time_nonnegative]
END;
GO
IF OBJECT_ID(N'analytics.fact_event', N'U') IS NULL
BEGIN
CREATE TABLE [analytics].[fact_event](
	[event_key] [bigint] IDENTITY(1,1) NOT NULL,
	[event_id] [bigint] NOT NULL,
	[match_key] [int] NOT NULL,
	[team_key] [int] NULL,
	[player_key] [int] NULL,
	[position_key] [int] NULL,
	[event_index] [int] NULL,
	[period_id] [int] NULL,
	[game_time_seconds] [float] NULL,
	[action_type] [nvarchar](50) NOT NULL,
	[action_detail] [nvarchar](100) NULL,
	[result] [nvarchar](20) NULL,
	[phase] [nvarchar](50) NULL,
	[pressure] [float] NULL,
	[start_x] [float] NULL,
	[start_y] [float] NULL,
	[end_x] [float] NULL,
	[end_y] [float] NULL,
 CONSTRAINT [PK_fact_event] PRIMARY KEY CLUSTERED 
(
	[event_key] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_fact_event_match_event] UNIQUE NONCLUSTERED 
(
	[match_key] ASC,
	[event_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [analytics].[fact_event]  WITH CHECK ADD  CONSTRAINT [FK_fact_event_match] FOREIGN KEY([match_key])
REFERENCES [analytics].[dim_match] ([match_key])

ALTER TABLE [analytics].[fact_event] CHECK CONSTRAINT [FK_fact_event_match]

ALTER TABLE [analytics].[fact_event]  WITH CHECK ADD  CONSTRAINT [FK_fact_event_player] FOREIGN KEY([player_key])
REFERENCES [analytics].[dim_player] ([player_key])

ALTER TABLE [analytics].[fact_event] CHECK CONSTRAINT [FK_fact_event_player]

ALTER TABLE [analytics].[fact_event]  WITH CHECK ADD  CONSTRAINT [FK_fact_event_position] FOREIGN KEY([position_key])
REFERENCES [analytics].[dim_position] ([position_key])

ALTER TABLE [analytics].[fact_event] CHECK CONSTRAINT [FK_fact_event_position]

ALTER TABLE [analytics].[fact_event]  WITH CHECK ADD  CONSTRAINT [FK_fact_event_team] FOREIGN KEY([team_key])
REFERENCES [analytics].[dim_team] ([team_key])

ALTER TABLE [analytics].[fact_event] CHECK CONSTRAINT [FK_fact_event_team]
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
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.match_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_match d WHERE d.match_id=s.match_id)) THROW 51000, N'Unmapped player_match_position.match_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_team d WHERE d.team_id=s.team_id)) THROW 51000, N'Unmapped player_match_position.team_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.player_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_player d WHERE d.player_id=s.player_id)) THROW 51000, N'Unmapped player_match_position.player_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.player_match_position s WHERE s.position_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_position d WHERE d.position_name=s.position_name)) THROW 51000, N'Unmapped player_match_position.position_name; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.match_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_match d WHERE d.match_id=s.match_id)) THROW 51000, N'Unmapped events.match_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.team_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_team d WHERE d.team_id=s.team_id)) THROW 51000, N'Unmapped events.team_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.player_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_player d WHERE d.player_id=s.player_id)) THROW 51000, N'Unmapped events.player_id; run 04 first.', 1;
IF EXISTS (SELECT 1 FROM staging.events s WHERE s.position_name IS NOT NULL AND NOT EXISTS (SELECT 1 FROM analytics.dim_position d WHERE d.position_name=s.position_name)) THROW 51000, N'Unmapped events.position_name; run 04 first.', 1;

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_time;
SELECT match_key, team_key, player_key, position_key, play_duration_seconds, match_share INTO #source_time FROM (SELECT m.match_key,t.team_key,p.player_key,x.position_key,s.play_duration_seconds,s.match_share FROM staging.player_match_position s JOIN analytics.dim_match m ON s.match_id=m.match_id JOIN analytics.dim_team t ON s.team_id=t.team_id JOIN analytics.dim_player p ON s.player_id=p.player_id JOIN analytics.dim_position x ON s.position_name=x.position_name) AS source_rows;
IF EXISTS (SELECT t.match_key, t.team_key, t.player_key, t.position_key, t.play_duration_seconds, t.match_share FROM analytics.fact_player_match_position t INNER JOIN #source_time s ON t.match_key=s.match_key AND t.team_key=s.team_key AND t.player_key=s.player_key AND t.position_key=s.position_key
           EXCEPT SELECT s.match_key, s.team_key, s.player_key, s.position_key, s.play_duration_seconds, s.match_share FROM analytics.fact_player_match_position t INNER JOIN #source_time s ON t.match_key=s.match_key AND t.team_key=s.team_key AND t.player_key=s.player_key AND t.position_key=s.position_key)
    THROW 51000, N'analytics.fact_player_match_position: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.fact_player_match_position (match_key, team_key, player_key, position_key, play_duration_seconds, match_share)
SELECT s.match_key, s.team_key, s.player_key, s.position_key, s.play_duration_seconds, s.match_share FROM #source_time s
WHERE NOT EXISTS (SELECT 1 FROM analytics.fact_player_match_position t WHERE t.match_key=s.match_key AND t.team_key=s.team_key AND t.player_key=s.player_key AND t.position_key=s.position_key);
IF EXISTS (SELECT match_key, team_key, player_key, position_key, play_duration_seconds, match_share FROM #source_time EXCEPT SELECT match_key, team_key, player_key, position_key, play_duration_seconds, match_share FROM analytics.fact_player_match_position)
 OR EXISTS (SELECT match_key, team_key, player_key, position_key, play_duration_seconds, match_share FROM analytics.fact_player_match_position EXCEPT SELECT match_key, team_key, player_key, position_key, play_duration_seconds, match_share FROM #source_time)
    THROW 51000, N'analytics.fact_player_match_position: source/target reconciliation failed.', 1;
DROP TABLE #source_time;

-- Append missing natural keys; stop rather than overwrite conflicting existing values.
DROP TABLE IF EXISTS #source_event;
SELECT event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y INTO #source_event FROM (SELECT s.event_id,m.match_key,t.team_key,p.player_key,x.position_key,s.event_index,s.period_id,s.game_time_seconds,s.action_type,s.action_detail,s.result,s.phase,s.pressure,s.start_x,s.start_y,s.end_x,s.end_y FROM staging.events s JOIN analytics.dim_match m ON s.match_id=m.match_id LEFT JOIN analytics.dim_team t ON s.team_id=t.team_id LEFT JOIN analytics.dim_player p ON s.player_id=p.player_id LEFT JOIN analytics.dim_position x ON s.position_name=x.position_name) AS source_rows;
IF EXISTS (SELECT t.event_id, t.match_key, t.team_key, t.player_key, t.position_key, t.event_index, t.period_id, t.game_time_seconds, t.action_type, t.action_detail, t.result, t.phase, t.pressure, t.start_x, t.start_y, t.end_x, t.end_y FROM analytics.fact_event t INNER JOIN #source_event s ON t.match_key=s.match_key AND t.event_id=s.event_id
           EXCEPT SELECT s.event_id, s.match_key, s.team_key, s.player_key, s.position_key, s.event_index, s.period_id, s.game_time_seconds, s.action_type, s.action_detail, s.result, s.phase, s.pressure, s.start_x, s.start_y, s.end_x, s.end_y FROM analytics.fact_event t INNER JOIN #source_event s ON t.match_key=s.match_key AND t.event_id=s.event_id)
    THROW 51000, N'analytics.fact_event: existing values differ from staging; investigate before reloading.', 1;
INSERT INTO analytics.fact_event (event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y)
SELECT s.event_id, s.match_key, s.team_key, s.player_key, s.position_key, s.event_index, s.period_id, s.game_time_seconds, s.action_type, s.action_detail, s.result, s.phase, s.pressure, s.start_x, s.start_y, s.end_x, s.end_y FROM #source_event s
WHERE NOT EXISTS (SELECT 1 FROM analytics.fact_event t WHERE t.match_key=s.match_key AND t.event_id=s.event_id);
IF EXISTS (SELECT event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y FROM #source_event EXCEPT SELECT event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y FROM analytics.fact_event)
 OR EXISTS (SELECT event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y FROM analytics.fact_event EXCEPT SELECT event_id, match_key, team_key, player_key, position_key, event_index, period_id, game_time_seconds, action_type, action_detail, result, phase, pressure, start_x, start_y, end_x, end_y FROM #source_event)
    THROW 51000, N'analytics.fact_event: source/target reconciliation failed.', 1;
DROP TABLE #source_event;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
THROW;
END CATCH;
GO
