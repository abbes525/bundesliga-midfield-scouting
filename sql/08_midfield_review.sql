-- Exact recovered view logic; CREATE OR ALTER makes deployment repeatable.
USE [FootballRecruitmentDW]
GO
/****** Objet : View [analytics].[vw_midfield_review] Date de script : 03/11/2026 21:47:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [analytics].[vw_midfield_review]
AS
WITH midfield_time AS (
    SELECT
        f.player_key,
        m.iteration_id,

        SUM(CASE
            WHEN m.season_half = N'H1'
            THEN f.play_duration_seconds ELSE 0
        END) AS h1_seconds,

        SUM(CASE
            WHEN m.season_half = N'H2'
            THEN f.play_duration_seconds ELSE 0
        END) AS h2_seconds

    FROM analytics.fact_player_match_position AS f

    INNER JOIN analytics.dim_match AS m
        ON f.match_key = m.match_key

    INNER JOIN analytics.dim_position AS pos
        ON f.position_key = pos.position_key

    WHERE pos.is_midfield = 1

    GROUP BY
        f.player_key,
        m.iteration_id
),
distinct_clubs AS (
    SELECT DISTINCT
        f.player_key,
        m.iteration_id,
        t.team_name

    FROM analytics.fact_player_match_position AS f

    INNER JOIN analytics.dim_match AS m
        ON f.match_key = m.match_key

    INNER JOIN analytics.dim_position AS pos
        ON f.position_key = pos.position_key

    INNER JOIN analytics.dim_team AS t
        ON f.team_key = t.team_key

    WHERE pos.is_midfield = 1
),
player_clubs AS (
    SELECT
        player_key,
        iteration_id,

        STRING_AGG(
            CAST(team_name AS NVARCHAR(MAX)),
            N' / '
        ) WITHIN GROUP (ORDER BY team_name) AS clubs

    FROM distinct_clubs

    GROUP BY
        player_key,
        iteration_id
)
SELECT
    s.*,
    c.clubs,

    h.h1_seconds / 60.0 AS h1_midfield_minutes,
    h.h2_seconds / 60.0 AS h2_midfield_minutes,

    CAST(
        CASE
            WHEN h.h1_seconds >= 450 * 60
             AND h.h2_seconds >= 450 * 60
            THEN 1 ELSE 0
        END
        AS BIT
    ) AS sufficient_minutes_both_halves,

    r.best_scenario_rank,
    r.worst_scenario_rank

FROM analytics.vw_midfield_screening AS s

INNER JOIN midfield_time AS h
    ON s.player_key = h.player_key
   AND s.iteration_id = h.iteration_id

LEFT JOIN player_clubs AS c
    ON s.player_key = c.player_key
   AND s.iteration_id = c.iteration_id

CROSS APPLY (
    SELECT
        MIN(v.scenario_rank) AS best_scenario_rank,
        MAX(v.scenario_rank) AS worst_scenario_rank
    FROM (
        VALUES
            (s.balanced_rank),
            (s.passing_focus_rank),
            (s.carrying_focus_rank)
    ) AS v(scenario_rank)
) AS r;
GO
