# Power BI report

Open **bundesliga_midfield_scouting.pbix** in Power BI Desktop. It is the supplied `Bundesliga_Midfield_Player_Profile_v3.pbix`, renamed without changing its bytes.

The saved data model contains Recruitment, the optional advanced summary, the player profile summary, and individual profile passes. Six visible pages cover the candidate overview, player comparison, scenario comparison, methodology, findings and player profile. The latest profile uses simple bar charts by pitch third rather than the superseded dot/pitch-image experiment.

The packaged report contains imported data and can be viewed without rebuilding SQL. Refresh requires your local SQL Server and the relevant SQL views. In Data source settings, change the server if your instance differs from `localhost\SQLEXPRESS`; keep the database as `FootballRecruitmentDW` unless you also update the SQL setup.

Core reporting view: `analytics.vw_recruitment_dashboard` (renamed Recruitment in the report). Profile views: `analytics.vw_player_profile_summary` and `analytics.vw_player_profile_passes`. Optional existing import: `analytics.vw_midfield_advanced_kpi_summary`.

The report's active player-key relationships connect the 79-player Recruitment table to the profile summary (1:1, both directions) and profile pass table (1:many, single direction). This is scoped to one season. A multi-season report would need player-season keys or a separate season dimension rather than assuming player_key alone is unique.

The supplied PBIX was structurally checked and its saved tables were inspected. Final native chart rendering and interaction must be checked in Power BI Desktop. Test a player change, the third-based bar charts, the 79/58 cards and navigation. Use Ctrl+click to activate page-navigation buttons in edit mode.

Screenshots are not included yet. Export actual report screenshots after checking the final version and put them in `reports/screenshots/`; do not present a mockup as a Power BI screenshot.
