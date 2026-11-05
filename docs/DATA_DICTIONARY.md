# Data and metric dictionary

## Grains and identifiers

| Dataset | One row represents | Key |
|---|---|---|
| Player directory | A provider player record | player_id |
| Team directory | A provider squad | team_id |
| Match directory | A match | match_id |
| Playing time | A player's participation at one position for one team in one match | match + team + player + position |
| Events | A recorded event | match + event_id |
| Recruitment report | An eligible player-season | player_key + iteration_id |
| Profile summary | An eligible player in iteration 743 | player_key |
| Profile passes | A candidate midfield PASS event in iteration 743 | event_key |
| Advanced KPI fact | One metric at a player-position-match-team record | match + team + player + position + KPI |
| Advanced KPI summary | One eligible player-season-metric | player_key + iteration_id + kpi_key |

Do not join events directly to position-duration rows and then sum minutes: one duration can be repeated for many events. Aggregate each fact at the required grain first.

## Core metrics

- `midfield_minutes`: recorded seconds at CENTRAL_MIDFIELD, DEFENSE_MIDFIELD or ATTACKING_MIDFIELD, divided by 60.
- `forward_pass_10m_count`: midfield PASS with provider SUCCESS and adjusted end_x − start_x ≥10.
- `forward_carry_10m_count`: the same rule for DRIBBLE.
- `final_third_*_entry_count`: successful pass/carry starting at x≤17.5 and ending at x>17.5.
- Per-90 rates: the qualifying count divided by midfield minutes, multiplied by 90.
- Passing/carrying percentiles: within-pool ranks of the forward action rates, not completion percentages.
- Defensive activity: average percentile of interception and loose-ball-regain rates.
- Balanced score: 0.35 × passing + 0.35 × carrying + 0.30 × defensive activity.
- Scenario rank range: worst rank minus best rank across the three weighting scenarios.

## Profile pass locations

Coordinates use the same adjusted orientation as the original analysis: a centred 105 × 68 metre pitch, attack toward positive x. The profile also provides shifted coordinates in 0–105 and 0–68 ranges.

- Defensive third: x < −17.5.
- Middle third: −17.5 ≤ x ≤17.5.
- Attacking third: x >17.5.
- Unknown: missing or out-of-bounds x or y at the relevant endpoint.

The left profile bar chart counts all pass attempts by starting third. The right chart counts only provider SUCCESS passes by ending third. Unknown endpoints remain a visible category when present. Neither chart measures expected threat or every location a player occupied.

Provider SUCCESS, NEUTRAL and FAIL are separate supplied outcome labels. A SUCCESS-only share is labelled `provider_success_share_pct`, not standard pass-completion percentage. Do not infer that every NEUTRAL pass is bad or every failed pass reflects a poor decision.

## Optional advanced metrics

| KPI ID | Name |
|---:|---|
| 0 | bypassed_opponents |
| 1404 | pxt_pass |
| 1405 | pxt_dribble |
| 1406 | pxt_setpiece |
| 1408 | pxt_shot |
| 1782 | expected_goal_assists |

`available_value_sum` adds the values actually present; all-NULL groups remain NULL. `observed_period_per90` uses minutes attached to records with values and may be biased by which records are missing. `season_per90` is NULL unless all expected records have a value. `ALL RECORDS PRESENT` describes record-value presence, not guaranteed capture of all real actions. Negative pxT values are preserved.

These provider contribution KPIs are distinct from `pxT.team`, a threat-state field that is not used or summed in this packaged analysis. Packing-zone and pressure-context additions remain future work.
