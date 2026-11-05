-- Exact recovered view logic; CREATE OR ALTER makes deployment repeatable.
USE [FootballRecruitmentDW]
GO
/****** Objet : View [analytics].[vw_midfield_screening] Date de script : 03/11/2026 21:47:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [analytics].[vw_midfield_screening]
AS
WITH metric_values AS (
    SELECT
        m.player_key,
        m.player_id,
        m.player_name,
        m.iteration_id,
        m.midfield_minutes,
        v.metric_name,
        v.metric_value

    FROM analytics.vw_midfield_metrics AS m

    CROSS APPLY (
        VALUES
            (N'forward_pass', m.forward_pass_10m_per90),
            (N'forward_carry', m.forward_carry_10m_per90),
            (N'third_entry_pass', m.final_third_pass_entries_per90),
            (N'third_entry_carry', m.final_third_carry_entries_per90),
            (N'interception', m.interceptions_per90),
            (N'loose_regain', m.loose_ball_regains_per90)
    ) AS v(metric_name, metric_value)
),
metric_ranks AS (
    SELECT
        *,

        RANK() OVER (
            PARTITION BY iteration_id, metric_name
            ORDER BY metric_value
        ) AS first_rank,

        COUNT(*) OVER (
            PARTITION BY iteration_id, metric_name, metric_value
        ) AS tied_players,

        COUNT(*) OVER (
            PARTITION BY iteration_id, metric_name
        ) AS pool_size

    FROM metric_values
),
metric_percentiles AS (
    SELECT
        *,

        100.0 * (
            first_rank + (tied_players - 1) / 2.0
        ) / pool_size AS percentile_value

    FROM metric_ranks
),
player_percentiles AS (
    SELECT
        player_key,
        player_id,
        player_name,
        iteration_id,
        midfield_minutes,

        MAX(CASE
            WHEN metric_name = N'forward_pass'
            THEN percentile_value
        END) AS forward_pass_pctile,

        MAX(CASE
            WHEN metric_name = N'forward_carry'
            THEN percentile_value
        END) AS forward_carry_pctile,

        MAX(CASE
            WHEN metric_name = N'third_entry_pass'
            THEN percentile_value
        END) AS third_entry_pass_pctile,

        MAX(CASE
            WHEN metric_name = N'third_entry_carry'
            THEN percentile_value
        END) AS third_entry_carry_pctile,

        MAX(CASE
            WHEN metric_name = N'interception'
            THEN percentile_value
        END) AS interception_pctile,

        MAX(CASE
            WHEN metric_name = N'loose_regain'
            THEN percentile_value
        END) AS loose_regain_pctile

    FROM metric_percentiles

    GROUP BY
        player_key,
        player_id,
        player_name,
        iteration_id,
        midfield_minutes
),
components AS (
    SELECT
        *,

        forward_pass_pctile AS passing_component,

        forward_carry_pctile AS carrying_component,

        (interception_pctile + loose_regain_pctile) / 2.0
            AS defensive_activity_component

    FROM player_percentiles
),
scores AS (
    SELECT
        *,

        0.35 * passing_component
        + 0.35 * carrying_component
        + 0.30 * defensive_activity_component
            AS balanced_score,

        0.50 * passing_component
        + 0.20 * carrying_component
        + 0.30 * defensive_activity_component
            AS passing_focus_score,

        0.20 * passing_component
        + 0.50 * carrying_component
        + 0.30 * defensive_activity_component
            AS carrying_focus_score

    FROM components
)
SELECT
    *,

    -- Preserve original scores; round only when determining ranks.
    RANK() OVER (
        PARTITION BY iteration_id
        ORDER BY ROUND(balanced_score, 6) DESC
    ) AS balanced_rank,

    RANK() OVER (
        PARTITION BY iteration_id
        ORDER BY ROUND(passing_focus_score, 6) DESC
    ) AS passing_focus_rank,

    RANK() OVER (
        PARTITION BY iteration_id
        ORDER BY ROUND(carrying_focus_score, 6) DESC
    ) AS carrying_focus_rank

FROM scores;
GO
