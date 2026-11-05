-- Exact recovered view logic; CREATE OR ALTER makes deployment repeatable.
USE [FootballRecruitmentDW]
GO
/****** Objet : View [analytics].[vw_midfield_pool] Date de script : 03/11/2026 21:47:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [analytics].[vw_midfield_pool]
AS
WITH player_time AS (
    SELECT
        f.player_key,
        m.iteration_id,

        SUM(f.play_duration_seconds) AS total_seconds,

        SUM(
            CASE
                WHEN pos.is_midfield = 1
                THEN f.play_duration_seconds
                ELSE 0
            END
        ) AS midfield_seconds

    FROM analytics.fact_player_match_position AS f

    INNER JOIN analytics.dim_position AS pos
        ON f.position_key = pos.position_key

    INNER JOIN analytics.dim_match AS m
        ON f.match_key = m.match_key

    GROUP BY
        f.player_key,
        m.iteration_id
)
SELECT
    p.player_key,
    p.player_id,
    p.player_name,
    pt.iteration_id,

    pt.total_seconds / 60.0 AS total_minutes,
    pt.midfield_seconds / 60.0 AS midfield_minutes,

    100.0 * (
        pt.midfield_seconds / NULLIF(pt.total_seconds, 0)
    ) AS midfield_share_pct

FROM player_time AS pt

INNER JOIN analytics.dim_player AS p
    ON pt.player_key = p.player_key

WHERE
    pt.midfield_seconds >= 900 * 60
    AND pt.midfield_seconds >= pt.total_seconds * 0.5;
GO

USE [FootballRecruitmentDW]
GO
/****** Objet : View [analytics].[vw_midfield_metrics] Date de script : 03/11/2026 21:47:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [analytics].[vw_midfield_metrics]
AS
WITH event_totals AS (
    SELECT
        e.player_key,
        m.iteration_id,

        SUM(CASE
            WHEN e.action_type = N'PASS'
             AND e.result = N'SUCCESS'
             AND e.end_x - e.start_x >= 10
            THEN 1 ELSE 0
        END) AS forward_pass_10m_count,

        SUM(CASE
            WHEN e.action_type = N'DRIBBLE'
             AND e.result = N'SUCCESS'
             AND e.end_x - e.start_x >= 10
            THEN 1 ELSE 0
        END) AS forward_carry_10m_count,

        SUM(CASE
            WHEN e.action_type = N'PASS'
             AND e.result = N'SUCCESS'
             AND e.start_x <= 17.5
             AND e.end_x > 17.5
            THEN 1 ELSE 0
        END) AS final_third_pass_entry_count,

        SUM(CASE
            WHEN e.action_type = N'DRIBBLE'
             AND e.result = N'SUCCESS'
             AND e.start_x <= 17.5
             AND e.end_x > 17.5
            THEN 1 ELSE 0
        END) AS final_third_carry_entry_count,

        SUM(CASE
            WHEN e.action_type = N'INTERCEPTION'
            THEN 1 ELSE 0
        END) AS interception_count,

        SUM(CASE
            WHEN e.action_type = N'LOOSE_BALL_REGAIN'
            THEN 1 ELSE 0
        END) AS loose_ball_regain_count

    FROM analytics.fact_event AS e

    INNER JOIN analytics.dim_position AS pos
        ON e.position_key = pos.position_key

    INNER JOIN analytics.dim_match AS m
        ON e.match_key = m.match_key

    WHERE pos.is_midfield = 1

    GROUP BY
        e.player_key,
        m.iteration_id
)
SELECT
    p.player_key,
    p.player_id,
    p.player_name,
    p.iteration_id,
    p.midfield_minutes,

    COALESCE(e.forward_pass_10m_count, 0)
        AS forward_pass_10m_count,

    COALESCE(e.forward_carry_10m_count, 0)
        AS forward_carry_10m_count,

    COALESCE(e.final_third_pass_entry_count, 0)
        AS final_third_pass_entry_count,

    COALESCE(e.final_third_carry_entry_count, 0)
        AS final_third_carry_entry_count,

    COALESCE(e.interception_count, 0)
        AS interception_count,

    COALESCE(e.loose_ball_regain_count, 0)
        AS loose_ball_regain_count,

    COALESCE(e.forward_pass_10m_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS forward_pass_10m_per90,

    COALESCE(e.forward_carry_10m_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS forward_carry_10m_per90,

    COALESCE(e.final_third_pass_entry_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS final_third_pass_entries_per90,

    COALESCE(e.final_third_carry_entry_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS final_third_carry_entries_per90,

    COALESCE(e.interception_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS interceptions_per90,

    COALESCE(e.loose_ball_regain_count, 0)
        * 90.0 / NULLIF(CAST(p.midfield_minutes AS FLOAT), 0)
        AS loose_ball_regains_per90

FROM analytics.vw_midfield_pool AS p

LEFT JOIN event_totals AS e
    ON p.player_key = e.player_key
   AND p.iteration_id = e.iteration_id;
GO
