-- Exact recovered view logic; CREATE OR ALTER makes deployment repeatable.
USE [FootballRecruitmentDW]
GO
/****** Objet : View [analytics].[vw_recruitment_dashboard] Date de script : 03/11/2026 21:47:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [analytics].[vw_recruitment_dashboard]
AS
SELECT
    r.player_key,
    r.player_id,
    r.player_name,
    r.iteration_id,
    r.clubs,

    r.midfield_minutes,
    r.h1_midfield_minutes,
    r.h2_midfield_minutes,
    r.sufficient_minutes_both_halves,

    -- Recorded action counts.
    m.forward_pass_10m_count,
    m.forward_carry_10m_count,
    m.final_third_pass_entry_count,
    m.final_third_carry_entry_count,
    m.interception_count,
    m.loose_ball_regain_count,

    -- Rates per 90 midfield minutes.
    m.forward_pass_10m_per90,
    m.forward_carry_10m_per90,
    m.final_third_pass_entries_per90,
    m.final_third_carry_entries_per90,
    m.interceptions_per90,
    m.loose_ball_regains_per90,

    -- Percentiles within the eligible season pool.
    r.forward_pass_pctile,
    r.forward_carry_pctile,
    r.third_entry_pass_pctile,
    r.third_entry_carry_pctile,
    r.interception_pctile,
    r.loose_regain_pctile,

    -- Screening components and scenarios.
    r.passing_component,
    r.carrying_component,
    r.defensive_activity_component,

    r.balanced_score,
    r.passing_focus_score,
    r.carrying_focus_score,

    r.balanced_rank,
    r.passing_focus_rank,
    r.carrying_focus_rank,
    r.best_scenario_rank,
    r.worst_scenario_rank

FROM analytics.vw_midfield_review AS r

INNER JOIN analytics.vw_midfield_metrics AS m
    ON r.player_key = m.player_key
   AND r.iteration_id = m.iteration_id;
GO
