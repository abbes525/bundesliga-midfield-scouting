/* Player Profile extension: Bundesliga 2023/24 (iteration 743).
   Run in SSMS, then import the TWO views named at the end into the existing PBIX.
   Creates views only. Does not change tables, scores, rankings or existing views.
   Passing scope: events at recorded midfield positions for the existing 79 candidates.
   Coordinate convention matches the existing analysis: centred 105 x 68 m pitch,
   attacking direction toward increasing x. NULL/out-of-bounds locations stay unknown.
   Provider SUCCESS / NEUTRAL / FAIL are retained; SUCCESS share is NOT labelled
   pass completion because provider NEUTRAL has its own meaning.
*/
USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW analytics.vw_player_profile_passes
AS
SELECT
    e.event_key, e.event_id, e.match_key, m.match_id, m.iteration_id,
    e.player_key, p.player_id, p.player_name, e.team_key,
    x.position_name, e.action_detail, e.phase,
    COALESCE(e.result, N'UNKNOWN') AS pass_result,
    e.start_x, e.start_y, e.end_x, e.end_y,
    CASE WHEN e.start_x BETWEEN -52.5 AND 52.5
          AND e.start_y BETWEEN -34.0 AND 34.0
         THEN e.start_x + 52.5 END AS start_pitch_x,
    CASE WHEN e.start_x BETWEEN -52.5 AND 52.5
          AND e.start_y BETWEEN -34.0 AND 34.0
         THEN e.start_y + 34.0 END AS start_pitch_y,
    CASE WHEN e.end_x BETWEEN -52.5 AND 52.5
          AND e.end_y BETWEEN -34.0 AND 34.0
         THEN e.end_x + 52.5 END AS end_pitch_x,
    CASE WHEN e.end_x BETWEEN -52.5 AND 52.5
          AND e.end_y BETWEEN -34.0 AND 34.0
         THEN e.end_y + 34.0 END AS end_pitch_y,
    CASE WHEN e.start_x IS NULL OR e.start_y IS NULL
           OR e.start_x NOT BETWEEN -52.5 AND 52.5
           OR e.start_y NOT BETWEEN -34.0 AND 34.0 THEN N'Unknown'
         WHEN e.start_x < -17.5 THEN N'Defensive third'
         WHEN e.start_x <= 17.5 THEN N'Middle third'
         ELSE N'Attacking third' END AS pass_start_third,
    CASE WHEN e.end_x IS NULL OR e.end_y IS NULL
           OR e.end_x NOT BETWEEN -52.5 AND 52.5
           OR e.end_y NOT BETWEEN -34.0 AND 34.0 THEN N'Unknown'
         WHEN e.end_x < -17.5 THEN N'Defensive third'
         WHEN e.end_x <= 17.5 THEN N'Middle third'
         ELSE N'Attacking third' END AS pass_end_third,
    CASE WHEN e.result = N'SUCCESS' AND e.end_x - e.start_x >= 10
         THEN 1 ELSE 0 END AS is_successful_forward_10m,
    CASE WHEN e.result = N'SUCCESS' AND e.start_x <= 17.5 AND e.end_x > 17.5
         THEN 1 ELSE 0 END AS is_successful_final_third_entry
FROM analytics.fact_event AS e
JOIN analytics.dim_match AS m ON m.match_key = e.match_key
JOIN analytics.dim_position AS x ON x.position_key = e.position_key
JOIN analytics.vw_midfield_pool AS p
  ON p.player_key = e.player_key AND p.iteration_id = m.iteration_id
WHERE m.iteration_id = 743 AND x.is_midfield = 1 AND e.action_type = N'PASS';
GO
CREATE OR ALTER VIEW analytics.vw_player_profile_summary
AS
WITH matches_played AS (
    SELECT f.player_key, m.iteration_id,
        COUNT(DISTINCT CASE WHEN f.play_duration_seconds > 0 THEN f.match_key END)
            AS matches_played_all_positions,
        COUNT(DISTINCT CASE WHEN f.play_duration_seconds > 0 AND x.is_midfield = 1
                            THEN f.match_key END) AS matches_played_midfield
    FROM analytics.fact_player_match_position AS f
    JOIN analytics.dim_match AS m ON m.match_key = f.match_key
    JOIN analytics.dim_position AS x ON x.position_key = f.position_key
    WHERE m.iteration_id = 743
    GROUP BY f.player_key, m.iteration_id
), passing AS (
    SELECT player_key, iteration_id, COUNT_BIG(*) AS midfield_pass_attempts,
        SUM(CASE WHEN pass_result = N'SUCCESS' THEN 1 ELSE 0 END) AS midfield_success_passes,
        SUM(CASE WHEN pass_result = N'NEUTRAL' THEN 1 ELSE 0 END) AS midfield_neutral_passes,
        SUM(CASE WHEN pass_result = N'FAIL' THEN 1 ELSE 0 END) AS midfield_failed_passes,
        SUM(CASE WHEN pass_result NOT IN (N'SUCCESS',N'NEUTRAL',N'FAIL')
                 THEN 1 ELSE 0 END) AS midfield_other_result_passes,
        SUM(CASE WHEN pass_start_third = N'Unknown' THEN 1 ELSE 0 END)
            AS passes_without_valid_start_location,
        SUM(CASE WHEN pass_end_third = N'Unknown' THEN 1 ELSE 0 END)
            AS passes_without_valid_end_location
    FROM analytics.vw_player_profile_passes
    GROUP BY player_key, iteration_id
)
SELECT p.player_key, p.player_id, p.player_name, p.iteration_id,
    p.total_minutes AS total_minutes_all_positions,
    p.midfield_minutes, p.midfield_share_pct,
    COALESCE(t.matches_played_all_positions,0) AS matches_played_all_positions,
    COALESCE(t.matches_played_midfield,0) AS matches_played_midfield,
    COALESCE(a.midfield_pass_attempts,0) AS midfield_pass_attempts,
    COALESCE(a.midfield_success_passes,0) AS midfield_success_passes,
    COALESCE(a.midfield_neutral_passes,0) AS midfield_neutral_passes,
    COALESCE(a.midfield_failed_passes,0) AS midfield_failed_passes,
    COALESCE(a.midfield_other_result_passes,0) AS midfield_other_result_passes,
    100.0 * a.midfield_success_passes / NULLIF(a.midfield_pass_attempts,0)
        AS provider_success_share_pct,
    a.midfield_pass_attempts * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT),0)
        AS midfield_pass_attempts_per90,
    COALESCE(a.passes_without_valid_start_location,0) AS passes_without_valid_start_location,
    COALESCE(a.passes_without_valid_end_location,0) AS passes_without_valid_end_location,
    k.forward_pass_10m_count, k.forward_carry_10m_count,
    k.final_third_pass_entry_count, k.final_third_carry_entry_count,
    k.interception_count, k.loose_ball_regain_count,
    k.forward_pass_10m_per90, k.forward_carry_10m_per90,
    k.final_third_pass_entries_per90, k.final_third_carry_entries_per90,
    k.interceptions_per90, k.loose_ball_regains_per90
FROM analytics.vw_midfield_pool AS p
LEFT JOIN matches_played AS t ON t.player_key=p.player_key AND t.iteration_id=p.iteration_id
LEFT JOIN passing AS a ON a.player_key=p.player_key AND a.iteration_id=p.iteration_id
JOIN analytics.vw_midfield_metrics AS k ON k.player_key=p.player_key AND k.iteration_id=p.iteration_id
WHERE p.iteration_id=743;
GO
-- Small checks; result should be PASS on all three rows.
SELECT N'Profile players' AS check_name,
       COUNT_BIG(*) AS actual_value, CAST(79 AS BIGINT) AS expected_value,
       CASE WHEN COUNT_BIG(*)=79 THEN N'PASS' ELSE N'FAIL' END AS result
FROM analytics.vw_player_profile_summary
UNION ALL
SELECT N'Pass outcome totals reconcile', COUNT_BIG(*), 0,
       CASE WHEN COUNT_BIG(*)=0 THEN N'PASS' ELSE N'FAIL' END
FROM analytics.vw_player_profile_summary
WHERE midfield_pass_attempts <> midfield_success_passes + midfield_neutral_passes
                             + midfield_failed_passes + midfield_other_result_passes
UNION ALL
SELECT N'Forward pass counts match existing analysis', COUNT_BIG(*), 0,
       CASE WHEN COUNT_BIG(*)=0 THEN N'PASS' ELSE N'FAIL' END
FROM analytics.vw_player_profile_summary AS s
LEFT JOIN (
    SELECT player_key, SUM(is_successful_forward_10m) AS forward_count
    FROM analytics.vw_player_profile_passes GROUP BY player_key
) AS a ON a.player_key=s.player_key
WHERE s.forward_pass_10m_count <> COALESCE(a.forward_count,0);
GO
SELECT TOP (5) player_name, total_minutes_all_positions, midfield_minutes,
    matches_played_midfield, midfield_pass_attempts, midfield_success_passes,
    midfield_neutral_passes, midfield_failed_passes
FROM analytics.vw_player_profile_summary ORDER BY player_name;
GO
/* Import into the EXISTING Power BI report:
   analytics.vw_player_profile_summary
   analytics.vw_player_profile_passes
   Save the PBIX and send it back. No need to build visuals or relationships yourself.
*/
