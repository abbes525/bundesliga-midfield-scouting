/*
Advanced KPI extension: six KPIs for the existing 79-candidate season snapshot.
Prerequisites:
  - Original dimensions and playing-time fact are populated.
  - Python loaded staging.player_match_position_kpi (12,690 rows).
Grain: match + team + player + position + KPI.
Preserves missing values, negative values, and both source value columns.
Does not change existing tables, views, scores, or rankings.
Existing matching rows are preserved; conflicting rows stop the load.
Table creation precedes the data transaction: a failed load can leave empty new tables.
This is a snapshot loader, not an update/migration or multi-season ingestion pipeline.
Save the earlier staging-table CREATE statement as 11_create_advanced_kpi_staging.sql.
*/
USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'analytics.dim_kpi', N'U') IS NULL
BEGIN
    CREATE TABLE analytics.dim_kpi (
        kpi_key INT IDENTITY(1,1) NOT NULL,
        kpi_id INT NOT NULL,
        kpi_name NVARCHAR(100) NOT NULL,
        kpi_label NVARCHAR(100) NOT NULL,
        CONSTRAINT PK_dim_kpi PRIMARY KEY (kpi_key),
        CONSTRAINT UQ_dim_kpi_id UNIQUE (kpi_id),
        CONSTRAINT UQ_dim_kpi_name UNIQUE (kpi_name)
    );
END;
GO

IF OBJECT_ID(N'analytics.fact_player_match_position_kpi', N'U') IS NULL
BEGIN
    CREATE TABLE analytics.fact_player_match_position_kpi (
        player_position_kpi_key BIGINT IDENTITY(1,1) NOT NULL,
        match_key INT NOT NULL,
        team_key INT NOT NULL,
        player_key INT NOT NULL,
        position_key INT NOT NULL,
        kpi_key INT NOT NULL,
        player_aggregate_value FLOAT NULL,
        event_export_value FLOAT NULL,
        CONSTRAINT PK_fact_player_match_position_kpi
            PRIMARY KEY (player_position_kpi_key),
        CONSTRAINT UQ_fact_player_match_position_kpi
            UNIQUE (match_key, team_key, player_key, position_key, kpi_key),
        CONSTRAINT FK_advanced_kpi_match FOREIGN KEY (match_key)
            REFERENCES analytics.dim_match(match_key),
        CONSTRAINT FK_advanced_kpi_team FOREIGN KEY (team_key)
            REFERENCES analytics.dim_team(team_key),
        CONSTRAINT FK_advanced_kpi_player FOREIGN KEY (player_key)
            REFERENCES analytics.dim_player(player_key),
        CONSTRAINT FK_advanced_kpi_position FOREIGN KEY (position_key)
            REFERENCES analytics.dim_position(position_key),
        CONSTRAINT FK_advanced_kpi_definition FOREIGN KEY (kpi_key)
            REFERENCES analytics.dim_kpi(kpi_key)
    );
END;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF (SELECT COUNT_BIG(*) FROM staging.player_match_position_kpi) <> 12690
        THROW 51000, N'Expected 12,690 advanced KPI staging rows for this snapshot.', 1;

    IF EXISTS (
        SELECT 1 FROM staging.player_match_position_kpi
        WHERE match_id IS NULL OR team_id IS NULL OR player_id IS NULL
           OR position_name IS NULL OR kpi_id IS NULL
    )
        THROW 51000, N'Advanced KPI source has missing identifiers.', 1;

    IF EXISTS (
        SELECT 1 FROM staging.player_match_position_kpi
        GROUP BY match_id, team_id, player_id, position_name, kpi_id
        HAVING COUNT_BIG(*) > 1
    )
        THROW 51000, N'Duplicate advanced KPI source keys.', 1;

    DECLARE @definitions TABLE (
        kpi_id INT PRIMARY KEY,
        kpi_name NVARCHAR(100),
        kpi_label NVARCHAR(100)
    );

    INSERT @definitions (kpi_id, kpi_name, kpi_label) VALUES
        (0, N'bypassed_opponents', N'Bypassed opponents'),
        (1404, N'pxt_pass', N'Passing pxT'),
        (1405, N'pxt_dribble', N'Carrying pxT'),
        (1406, N'pxt_setpiece', N'Set-piece pxT'),
        (1408, N'pxt_shot', N'Shooting pxT'),
        (1782, N'expected_goal_assists', N'Expected goal assists');

    IF EXISTS (
        SELECT 1 FROM staging.player_match_position_kpi s
        LEFT JOIN @definitions d ON s.kpi_id = d.kpi_id
        WHERE d.kpi_id IS NULL
    )
        THROW 51000, N'Unexpected KPI ID in staging.', 1;

    IF EXISTS (
        SELECT 1 FROM staging.player_match_position_kpi
        GROUP BY match_id, team_id, player_id, position_name
        HAVING COUNT(*) <> 6
    )
        THROW 51000, N'Each player-position-match must have six KPI rows, including NULL values.', 1;

    IF EXISTS (
        SELECT 1 FROM analytics.dim_kpi k
        JOIN @definitions d ON k.kpi_id = d.kpi_id
        WHERE k.kpi_name <> d.kpi_name OR k.kpi_label <> d.kpi_label
    )
        THROW 51000, N'Existing KPI definitions conflict with this script.', 1;

    INSERT analytics.dim_kpi (kpi_id, kpi_name, kpi_label)
    SELECT d.kpi_id, d.kpi_name, d.kpi_label FROM @definitions d
    WHERE NOT EXISTS (
        SELECT 1 FROM analytics.dim_kpi k WHERE k.kpi_id = d.kpi_id
    );

    DROP TABLE IF EXISTS #advanced_expected;

    SELECT
        m.match_key, t.team_key, p.player_key, x.position_key, k.kpi_key,
        s.player_aggregate_value, s.event_export_value
    INTO #advanced_expected
    FROM staging.player_match_position_kpi s
    JOIN analytics.dim_match m ON s.match_id = m.match_id
    JOIN analytics.dim_team t ON s.team_id = t.team_id
    JOIN analytics.dim_player p ON s.player_id = p.player_id
    JOIN analytics.dim_position x ON s.position_name = x.position_name
    JOIN analytics.dim_kpi k ON s.kpi_id = k.kpi_id
    JOIN analytics.fact_player_match_position pt
      ON pt.match_key = m.match_key AND pt.team_key = t.team_key
     AND pt.player_key = p.player_key AND pt.position_key = x.position_key
    WHERE m.iteration_id = 743 AND x.is_midfield = 1;

    IF (SELECT COUNT_BIG(*) FROM #advanced_expected) <> 12690
        THROW 51000, N'Some KPI rows did not map to the expected season, dimensions, midfield positions, or playing-time record.', 1;

    IF (SELECT COUNT(DISTINCT player_key) FROM #advanced_expected) <> 79
        THROW 51000, N'Expected 79 advanced KPI candidate players.', 1;

    IF EXISTS (
        SELECT 1 FROM #advanced_expected e
        WHERE NOT EXISTS (
            SELECT 1 FROM analytics.vw_midfield_pool pool
            WHERE pool.player_key = e.player_key AND pool.iteration_id = 743
        )
    )
        THROW 51000, N'An advanced KPI player is outside the original candidate pool.', 1;

    -- Never replace an existing value silently. EXCEPT compares NULLs correctly.
    IF EXISTS (
        SELECT f.match_key, f.team_key, f.player_key, f.position_key, f.kpi_key,
               f.player_aggregate_value, f.event_export_value
        FROM analytics.fact_player_match_position_kpi f
        JOIN #advanced_expected e
          ON f.match_key=e.match_key AND f.team_key=e.team_key
         AND f.player_key=e.player_key AND f.position_key=e.position_key
         AND f.kpi_key=e.kpi_key
        EXCEPT
        SELECT match_key, team_key, player_key, position_key, kpi_key,
               player_aggregate_value, event_export_value
        FROM #advanced_expected
    )
        THROW 51000, N'Existing advanced fact values differ from staging; investigate before reloading.', 1;

    INSERT analytics.fact_player_match_position_kpi (
        match_key, team_key, player_key, position_key, kpi_key,
        player_aggregate_value, event_export_value
    )
    SELECT e.match_key, e.team_key, e.player_key, e.position_key, e.kpi_key,
           e.player_aggregate_value, e.event_export_value
    FROM #advanced_expected e
    WHERE NOT EXISTS (
        SELECT 1 FROM analytics.fact_player_match_position_kpi f
        WHERE f.match_key=e.match_key AND f.team_key=e.team_key
          AND f.player_key=e.player_key AND f.position_key=e.position_key
          AND f.kpi_key=e.kpi_key
    );

    IF EXISTS (
        SELECT match_key, team_key, player_key, position_key, kpi_key,
               player_aggregate_value, event_export_value FROM #advanced_expected
        EXCEPT
        SELECT match_key, team_key, player_key, position_key, kpi_key,
               player_aggregate_value, event_export_value
        FROM analytics.fact_player_match_position_kpi
    ) OR EXISTS (
        SELECT match_key, team_key, player_key, position_key, kpi_key,
               player_aggregate_value, event_export_value
        FROM analytics.fact_player_match_position_kpi
        EXCEPT
        SELECT match_key, team_key, player_key, position_key, kpi_key,
               player_aggregate_value, event_export_value FROM #advanced_expected
    )
        THROW 51000, N'Advanced fact source/target reconciliation failed.', 1;

    COMMIT TRANSACTION;
    DROP TABLE #advanced_expected;

    SELECT
        COUNT_BIG(*) AS advanced_fact_rows,
        COUNT(DISTINCT player_key) AS candidate_players,
        COUNT(DISTINCT kpi_key) AS metric_types,
        SUM(CASE WHEN event_export_value IS NOT NULL THEN 1 ELSE 0 END)
            AS event_supplied_values
    FROM analytics.fact_player_match_position_kpi;

    SELECT
        k.kpi_id, k.kpi_name, COUNT_BIG(*) AS position_match_records,
        COUNT(f.player_aggregate_value) AS aggregate_values_present,
        COUNT(f.event_export_value) AS event_values_present,
        SUM(CASE WHEN f.player_aggregate_value IS NULL
                  AND f.event_export_value IS NULL THEN 1 ELSE 0 END)
            AS unresolved_records
    FROM analytics.fact_player_match_position_kpi f
    JOIN analytics.dim_kpi k ON f.kpi_key=k.kpi_key
    GROUP BY k.kpi_id, k.kpi_name
    ORDER BY k.kpi_id;

    PRINT N'Advanced KPI dimensions and fact loaded. All source keys and values reconcile.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
