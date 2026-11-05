/*
Run after 12_create_load_advanced_kpis.sql.
Creates TWO NEW views; existing reporting views and scores are unchanged.

Value policy:
  1. Prefer the original player aggregate when present (including zero).
  2. Otherwise use the separately stored event-export supplement.
  3. Otherwise preserve NULL. Never infer zero from absence.

Record presence is NOT proof of complete real-world action capture.
observed_period_per90 uses only durations attached to records with values;
it describes a selected sample, not an estimated full-season rate.
This is particularly important for shot/set-piece KPIs, where absent entries
may reflect no relevant action. Partial sample rates are not fair season rankings.
season_per90 is returned only when all expected midfield position-match
records have a value. Supplied event exports may differ in version from
the saved player aggregates; supplement provenance is retained.

The summary is LONG: one player + season + KPI per row (79 x 6 = 474).
Do not sum its repeated midfield_minutes across different KPIs.
The detailed view is also long: each playing-time record appears per KPI.
*/
USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER VIEW analytics.vw_midfield_advanced_kpi_records
AS
SELECT
    f.player_position_kpi_key,
    f.match_key,
    m.match_id,
    m.iteration_id,
    f.team_key,
    t.team_id,
    f.player_key,
    p.player_id,
    p.player_name,
    f.position_key,
    x.position_name,
    f.kpi_key,
    k.kpi_id,
    k.kpi_name AS metric,
    k.kpi_label,
    pt.play_duration_seconds,
    f.player_aggregate_value,
    f.event_export_value,
    COALESCE(f.player_aggregate_value, f.event_export_value) AS analysis_value,
    CASE
        WHEN f.player_aggregate_value IS NOT NULL THEN N'player_aggregate'
        WHEN f.event_export_value IS NOT NULL THEN N'event_export'
        ELSE N'unresolved'
    END AS value_source
FROM analytics.fact_player_match_position_kpi f
JOIN analytics.dim_match m ON f.match_key=m.match_key
JOIN analytics.dim_team t ON f.team_key=t.team_key
JOIN analytics.dim_player p ON f.player_key=p.player_key
JOIN analytics.dim_position x ON f.position_key=x.position_key
JOIN analytics.dim_kpi k ON f.kpi_key=k.kpi_key
JOIN analytics.fact_player_match_position pt
  ON f.match_key=pt.match_key AND f.team_key=pt.team_key
 AND f.player_key=pt.player_key AND f.position_key=pt.position_key
JOIN analytics.vw_midfield_pool pool
  ON pool.player_key=f.player_key AND pool.iteration_id=m.iteration_id
WHERE x.is_midfield=1
  AND k.kpi_id IN (0,1404,1405,1406,1408,1782);
GO

CREATE OR ALTER VIEW analytics.vw_midfield_advanced_kpi_summary
AS
WITH expected_records AS (
    -- Count playing-time records independently of KPI presence.
    SELECT pt.player_key, m.iteration_id, COUNT_BIG(*) AS total_records
    FROM analytics.fact_player_match_position pt
    JOIN analytics.dim_match m ON pt.match_key=m.match_key
    JOIN analytics.dim_position x ON pt.position_key=x.position_key
    WHERE x.is_midfield=1
    GROUP BY pt.player_key,m.iteration_id
),
aggregated AS (
    SELECT
        player_key,iteration_id,kpi_key,
        COUNT_BIG(*) AS kpi_records_present,
        COUNT(analysis_value) AS populated_records,
        SUM(analysis_value) AS available_value_sum,
        SUM(CASE WHEN analysis_value IS NOT NULL
                 THEN CAST(play_duration_seconds AS FLOAT) ELSE 0.0 END)
            / 60.0 AS minutes_with_value,
        SUM(CASE WHEN value_source=N'event_export' THEN 1 ELSE 0 END)
            AS supplemented_records
    FROM analytics.vw_midfield_advanced_kpi_records
    GROUP BY player_key,iteration_id,kpi_key
),
summary_base AS (
    -- Start from every eligible player x KPI, even if every value is NULL.
    SELECT
        pool.player_key,pool.player_id,pool.player_name,pool.iteration_id,
        k.kpi_key,k.kpi_id,k.kpi_name AS metric,k.kpi_label,
        e.total_records,
        pool.midfield_minutes,
        COALESCE(a.kpi_records_present,0) AS kpi_records_present,
        COALESCE(a.populated_records,0) AS populated_records,
        e.total_records-COALESCE(a.populated_records,0) AS unresolved_records,
        a.available_value_sum,
        COALESCE(a.minutes_with_value,0.0) AS minutes_with_value,
        COALESCE(a.supplemented_records,0) AS supplemented_records
    FROM analytics.vw_midfield_pool pool
    JOIN expected_records e
      ON e.player_key=pool.player_key AND e.iteration_id=pool.iteration_id
    CROSS JOIN analytics.dim_kpi k
    LEFT JOIN aggregated a
      ON a.player_key=pool.player_key AND a.iteration_id=pool.iteration_id
     AND a.kpi_key=k.kpi_key
    WHERE k.kpi_id IN (0,1404,1405,1406,1408,1782)
)
SELECT
    player_key,player_id,player_name,iteration_id,kpi_key,kpi_id,metric,kpi_label,
    total_records,kpi_records_present,populated_records,unresolved_records,
    midfield_minutes,minutes_with_value,
    100.0*populated_records/NULLIF(total_records,0) AS record_presence_pct,
    100.0*minutes_with_value/NULLIF(CAST(midfield_minutes AS FLOAT),0)
        AS minutes_with_value_pct,
    available_value_sum,
    available_value_sum*90.0/NULLIF(minutes_with_value,0)
        AS observed_period_per90,
    CASE WHEN unresolved_records=0
         THEN available_value_sum*90.0/NULLIF(CAST(midfield_minutes AS FLOAT),0)
         ELSE NULL END AS season_per90,
    supplemented_records,
    CASE WHEN unresolved_records=0 THEN N'ALL RECORDS PRESENT'
         ELSE N'PARTIAL' END AS data_status
FROM summary_base;
GO

-- Read-only snapshot checks. A failed check does not modify stored data;
-- the new views remain available for inspection.
SET NOCOUNT ON;
DECLARE @checks TABLE (
    check_name NVARCHAR(160),actual_value BIGINT,expected_value BIGINT
);

INSERT @checks SELECT N'Detailed KPI rows',COUNT_BIG(*),12690
FROM analytics.vw_midfield_advanced_kpi_records WHERE iteration_id=743;

INSERT @checks SELECT N'Player-season-KPI summary rows',COUNT_BIG(*),474
FROM analytics.vw_midfield_advanced_kpi_summary WHERE iteration_id=743;

INSERT @checks SELECT N'Candidate players',COUNT(DISTINCT player_key),79
FROM analytics.vw_midfield_advanced_kpi_summary WHERE iteration_id=743;

INSERT @checks SELECT N'Metric types',COUNT(DISTINCT kpi_id),6
FROM analytics.vw_midfield_advanced_kpi_summary WHERE iteration_id=743;

INSERT @checks SELECT N'Event-supplemented values',SUM(supplemented_records),2
FROM analytics.vw_midfield_advanced_kpi_summary WHERE iteration_id=743;

INSERT @checks SELECT N'Duplicate player-season-KPI summaries',COUNT_BIG(*),0
FROM (
    SELECT player_key,iteration_id,kpi_id
    FROM analytics.vw_midfield_advanced_kpi_summary
    GROUP BY player_key,iteration_id,kpi_id HAVING COUNT_BIG(*)>1
) d;

INSERT @checks SELECT N'Missing or unexpected KPI rows per player',COUNT_BIG(*),0
FROM analytics.vw_midfield_advanced_kpi_summary
WHERE iteration_id=743 AND kpi_records_present<>total_records;

INSERT @checks SELECT N'Invalid presence counts or minutes',COUNT_BIG(*),0
FROM analytics.vw_midfield_advanced_kpi_summary
WHERE iteration_id=743 AND (
    unresolved_records<0 OR populated_records>total_records
    OR minutes_with_value<0
    OR minutes_with_value>CAST(midfield_minutes AS FLOAT)+0.00001
    OR populated_records+unresolved_records<>total_records
);

INSERT @checks SELECT N'Invalid full-season rate status',COUNT_BIG(*),0
FROM analytics.vw_midfield_advanced_kpi_summary
WHERE iteration_id=743 AND (
    (unresolved_records>0 AND season_per90 IS NOT NULL)
    OR (unresolved_records=0 AND season_per90 IS NULL)
);

SELECT check_name,actual_value,expected_value,
       CASE WHEN actual_value=expected_value THEN N'PASS' ELSE N'FAIL' END AS result
FROM @checks;

SELECT kpi_id,metric,COUNT(*) AS candidate_players,
       SUM(total_records) AS total_records,
       SUM(populated_records) AS populated_records,
       SUM(unresolved_records) AS unresolved_records,
       SUM(supplemented_records) AS supplemented_records,
       SUM(CASE WHEN data_status=N'ALL RECORDS PRESENT' THEN 1 ELSE 0 END)
           AS players_all_records_present
FROM analytics.vw_midfield_advanced_kpi_summary
WHERE iteration_id=743
GROUP BY kpi_id,metric ORDER BY kpi_id;

SELECT player_name,metric,available_value_sum,observed_period_per90,season_per90,
       minutes_with_value_pct,unresolved_records,supplemented_records,data_status
FROM analytics.vw_midfield_advanced_kpi_summary
WHERE iteration_id=743
  AND player_name IN (N'Xaver Schlager',N'Granit Xhaka',N'Anton Stach',
                      N'Angelo Stiller',N'Florian Wirtz')
ORDER BY player_name,metric;

IF EXISTS (
    SELECT 1 FROM @checks WHERE actual_value IS NULL OR actual_value<>expected_value
)
    THROW 51000,N'Advanced KPI view validation failed; inspect results above.',1;

PRINT N'Advanced KPI views created. All snapshot checks passed.';
GO
