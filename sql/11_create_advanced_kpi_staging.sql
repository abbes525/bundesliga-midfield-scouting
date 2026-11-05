-- Optional advanced KPI extension. Run before notebook extensions/02 and SQL 12.
-- Restores the staging definition missing from the uploaded project.
USE [FootballRecruitmentDW];
GO
IF OBJECT_ID(N'staging.player_match_position_kpi', N'U') IS NULL
BEGIN
    CREATE TABLE staging.player_match_position_kpi (
        match_id INT NOT NULL,
        team_id INT NOT NULL,
        player_id INT NOT NULL,
        position_name NVARCHAR(50) NOT NULL,
        kpi_id INT NOT NULL,
        player_aggregate_value FLOAT NULL,
        event_export_value FLOAT NULL,
        CONSTRAINT PK_staging_player_match_position_kpi
            PRIMARY KEY (match_id, team_id, player_id, position_name, kpi_id)
    );
END;
GO
