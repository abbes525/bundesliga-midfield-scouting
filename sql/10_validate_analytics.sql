USE [FootballRecruitmentDW];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
-- Read-only validation for the complete Bundesliga 2023/24 snapshot (iteration 743).
DECLARE @iteration_id INT=743;
DECLARE @checks TABLE(check_name NVARCHAR(200), actual_value DECIMAL(38,6), expected_value DECIMAL(38,6));
INSERT @checks SELECT N'staging.players rows',COUNT_BIG(*),570 FROM staging.players;
INSERT @checks SELECT N'staging.teams rows',COUNT_BIG(*),18 FROM staging.teams;
INSERT @checks SELECT N'staging.matches rows',COUNT_BIG(*),306 FROM staging.matches;
INSERT @checks SELECT N'staging.player_match_position rows',COUNT_BIG(*),10577 FROM staging.player_match_position;
INSERT @checks SELECT N'staging.events rows',COUNT_BIG(*),939200 FROM staging.events;
INSERT @checks SELECT N'analytics.dim_player rows',COUNT_BIG(*),570 FROM analytics.dim_player;
INSERT @checks SELECT N'analytics.dim_team rows',COUNT_BIG(*),18 FROM analytics.dim_team;
INSERT @checks SELECT N'analytics.dim_position rows',COUNT_BIG(*),10 FROM analytics.dim_position;
INSERT @checks SELECT N'analytics.dim_match rows',COUNT_BIG(*),306 FROM analytics.dim_match;
INSERT @checks SELECT N'analytics.fact_player_match_position rows',COUNT_BIG(*),10577 FROM analytics.fact_player_match_position;
INSERT @checks SELECT N'analytics.fact_event rows',COUNT_BIG(*),939200 FROM analytics.fact_event;
INSERT @checks SELECT N'vw_midfield_pool candidates',COUNT_BIG(*),79 FROM analytics.vw_midfield_pool WHERE iteration_id=@iteration_id;
INSERT @checks SELECT N'vw_midfield_metrics candidates',COUNT_BIG(*),79 FROM analytics.vw_midfield_metrics WHERE iteration_id=@iteration_id;
INSERT @checks SELECT N'vw_midfield_screening candidates',COUNT_BIG(*),79 FROM analytics.vw_midfield_screening WHERE iteration_id=@iteration_id;
INSERT @checks SELECT N'vw_midfield_review candidates',COUNT_BIG(*),79 FROM analytics.vw_midfield_review WHERE iteration_id=@iteration_id;
INSERT @checks SELECT N'vw_recruitment_dashboard candidates',COUNT_BIG(*),79 FROM analytics.vw_recruitment_dashboard WHERE iteration_id=@iteration_id;
INSERT @checks SELECT N'Meets both-half minutes rule',COUNT_BIG(*),58 FROM analytics.vw_recruitment_dashboard WHERE iteration_id=@iteration_id AND sufficient_minutes_both_halves=1;
INSERT @checks SELECT N'Duplicate dashboard player/season keys',COUNT_BIG(*),0 FROM
 (SELECT player_key,iteration_id FROM analytics.vw_recruitment_dashboard GROUP BY player_key,iteration_id HAVING COUNT_BIG(*)>1) d;
INSERT @checks SELECT N'Playing seconds difference',
 (SELECT SUM(play_duration_seconds) FROM analytics.fact_player_match_position)-(SELECT SUM(play_duration_seconds) FROM staging.player_match_position),0;
INSERT @checks SELECT N'Participating players',COUNT(DISTINCT player_key),494 FROM analytics.fact_player_match_position;
INSERT @checks SELECT N'Invalid minutes flags',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard
 WHERE sufficient_minutes_both_halves<>CAST(CASE WHEN h1_midfield_minutes>=450 AND h2_midfield_minutes>=450 THEN 1 ELSE 0 END AS BIT);
INSERT @checks SELECT N'Invalid half-minute totals',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard
 WHERE ABS(midfield_minutes-h1_midfield_minutes-h2_midfield_minutes)>0.00001;
INSERT @checks SELECT N'Invalid scenario extremes',COUNT_BIG(*),0 FROM analytics.vw_midfield_review s
 CROSS APPLY(SELECT MIN(v.r) lo,MAX(v.r) hi FROM(VALUES(s.balanced_rank),(s.passing_focus_rank),(s.carrying_focus_rank))v(r)) a
 WHERE best_scenario_rank<>a.lo OR worst_scenario_rank<>a.hi;
INSERT @checks SELECT N'Top-five shortlist rows',COUNT_BIG(*),5 FROM analytics.vw_recruitment_dashboard WHERE iteration_id=@iteration_id AND balanced_rank<=5 AND sufficient_minutes_both_halves=1;
-- Stable reference results from the previously reconciled SQL/Python output.
INSERT @checks SELECT N'Top-five reference mismatches',COUNT_BIG(*),0 FROM
 (VALUES(N'Xaver Schlager',1,90.32,1,1),(N'Granit Xhaka',2,88.99,1,2),(N'Anton Stach',3,85.25,3,4),(N'Emre Can',4,83.42,3,6),(N'Kevin Stöger',5,82.47,5,5)) e(player_name,balanced_rank,score,best_rank,worst_rank)
 LEFT JOIN analytics.vw_recruitment_dashboard d ON d.player_name=e.player_name AND d.iteration_id=@iteration_id
 WHERE d.player_key IS NULL OR d.balanced_rank<>e.balanced_rank OR ABS(d.balanced_score-e.score)>0.0051 OR d.best_scenario_rank<>e.best_rank OR d.worst_scenario_rank<>e.worst_rank;
INSERT @checks SELECT N'Xhaka and Schlager passing-rank tie',COUNT_BIG(*),2 FROM analytics.vw_recruitment_dashboard WHERE iteration_id=@iteration_id AND player_name IN(N'Granit Xhaka',N'Xaver Schlager') AND passing_focus_rank=1;
INSERT @checks SELECT N'forward_pass_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE forward_pass_pctile IS NULL OR forward_pass_pctile<0 OR forward_pass_pctile>100;
INSERT @checks SELECT N'forward_carry_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE forward_carry_pctile IS NULL OR forward_carry_pctile<0 OR forward_carry_pctile>100;
INSERT @checks SELECT N'third_entry_pass_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE third_entry_pass_pctile IS NULL OR third_entry_pass_pctile<0 OR third_entry_pass_pctile>100;
INSERT @checks SELECT N'third_entry_carry_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE third_entry_carry_pctile IS NULL OR third_entry_carry_pctile<0 OR third_entry_carry_pctile>100;
INSERT @checks SELECT N'interception_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE interception_pctile IS NULL OR interception_pctile<0 OR interception_pctile>100;
INSERT @checks SELECT N'loose_regain_pctile outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE loose_regain_pctile IS NULL OR loose_regain_pctile<0 OR loose_regain_pctile>100;
INSERT @checks SELECT N'balanced_score outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE balanced_score IS NULL OR balanced_score<0 OR balanced_score>100;
INSERT @checks SELECT N'passing_focus_score outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE passing_focus_score IS NULL OR passing_focus_score<0 OR passing_focus_score>100;
INSERT @checks SELECT N'carrying_focus_score outside 0..100 or NULL',COUNT_BIG(*),0 FROM analytics.vw_recruitment_dashboard WHERE carrying_focus_score IS NULL OR carrying_focus_score<0 OR carrying_focus_score>100;
SELECT check_name,actual_value,expected_value,
 CASE WHEN actual_value=expected_value THEN N'PASS' ELSE N'FAIL' END AS result FROM @checks;
SELECT player_name,clubs,balanced_rank,best_scenario_rank,worst_scenario_rank,ROUND(balanced_score,2) AS balanced_score,h1_midfield_minutes,h2_midfield_minutes
 FROM analytics.vw_recruitment_dashboard WHERE iteration_id=@iteration_id AND balanced_rank<=5 AND sufficient_minutes_both_halves=1 ORDER BY balanced_rank;
IF EXISTS(SELECT 1 FROM @checks WHERE actual_value IS NULL OR actual_value<>expected_value)
 THROW 51000,N'One or more checks failed. Review the results above; no data was changed.',1;
PRINT N'All snapshot validation checks passed.';
