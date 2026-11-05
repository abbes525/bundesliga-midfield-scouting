USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Existing tables are preserved. Load raw data using your Python import after this file.
IF OBJECT_ID(N'staging.players', N'U') IS NULL
BEGIN
CREATE TABLE [staging].[players](
	[player_id] [int] NULL,
	[player_name] [nvarchar](200) NULL,
	[first_name] [nvarchar](200) NULL,
	[last_name] [nvarchar](200) NULL,
	[birth_date] [date] NULL,
	[preferred_foot] [nvarchar](20) NULL
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'staging.teams', N'U') IS NULL
BEGIN
CREATE TABLE [staging].[teams](
	[team_id] [int] NULL,
	[team_name] [nvarchar](200) NULL,
	[country_id] [int] NULL,
	[team_type] [nvarchar](50) NULL,
	[gender] [nvarchar](20) NULL
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'staging.matches', N'U') IS NULL
BEGIN
CREATE TABLE [staging].[matches](
	[match_id] [int] NULL,
	[iteration_id] [int] NULL,
	[home_team_id] [int] NULL,
	[away_team_id] [int] NULL,
	[kickoff_utc] [datetime2](3) NULL,
	[matchday] [smallint] NULL,
	[available] [bit] NULL
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'staging.player_match_position', N'U') IS NULL
BEGIN
CREATE TABLE [staging].[player_match_position](
	[match_id] [int] NULL,
	[team_id] [int] NULL,
	[player_id] [int] NULL,
	[position_name] [nvarchar](50) NULL,
	[play_duration_seconds] [decimal](18, 6) NULL,
	[match_share] [decimal](12, 10) NULL
) ON [PRIMARY]
END;
GO
IF OBJECT_ID(N'staging.events', N'U') IS NULL
BEGIN
CREATE TABLE [staging].[events](
	[match_id] [int] NULL,
	[event_id] [bigint] NULL,
	[event_index] [int] NULL,
	[period_id] [int] NULL,
	[game_time_seconds] [float] NULL,
	[team_id] [int] NULL,
	[player_id] [int] NULL,
	[position_name] [nvarchar](50) NULL,
	[action_type] [nvarchar](50) NULL,
	[action_detail] [nvarchar](100) NULL,
	[result] [nvarchar](20) NULL,
	[phase] [nvarchar](50) NULL,
	[pressure] [float] NULL,
	[start_x] [float] NULL,
	[start_y] [float] NULL,
	[end_x] [float] NULL,
	[end_y] [float] NULL
) ON [PRIMARY]
END;
GO
