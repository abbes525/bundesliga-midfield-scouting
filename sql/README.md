# SQL execution guide

The numbered scripts target `FootballRecruitmentDW` on SQL Server. Run them in SSMS, one file at a time, and stop on errors. They are T-SQL, not MySQL. Core scripts 01–10 and the extension/profile scripts are all included.

## Existing working database

Do **not** rebuild or rerun the staging imports. Run `10_validate_analytics.sql` to check the core snapshot. SQL 14 creates the profile views if needed. Optional scripts 11–13 concern advanced KPIs and do not change the core scores.

## Fresh core build

| Step | Action | Why |
|---|---|---|
| 1 | Run `01_create_database.sql` | Create database and staging/analytics schemas if absent. |
| 2 | Run `02_create_staging_tables.sql` | Define five source tables. |
| 3 | Run notebook `01_data_preparation_and_screening.ipynb` | Cache/validate source files and calculate Python references. This can also be done before step 1. |
| 4 | Run notebook `02_sql_staging_import.ipynb` with its load flag enabled | Import five prepared source tables. Targets must be empty. |
| 5 | Run `03_validate_staging.sql` | Check required fields, keys, references, durations and source counts. |
| 6 | Run `04_create_load_dimensions.sql` | Create/load player, team, position and match dimensions. |
| 7 | Run `05_create_load_facts.sql` | Create/load the event and playing-time facts. |
| 8 | Run `06_analytical_views.sql` | Define candidate eligibility and six event metrics. |
| 9 | Run `07_midfield_screening.sql` | Calculate percentiles and three scoring/ranking scenarios. |
| 10 | Run `08_midfield_review.sql` and `09_reporting_view.sql` | Add clubs, half-season exposure and the reporting view. |
| 11 | Run `10_validate_analytics.sql` | Check the fixed snapshot; expected 35 PASS results. |
| 12 | Run notebook `03_sql_result_validation.ipynb` | Compare SQL with the independent Python calculation. |
| 13 | Run `14_create_player_profile_views.sql` | Add summary and individual-pass views for the profile page. Expected three PASS results. |

## Optional advanced KPI extension

Run only if you want to reproduce the saved advanced exploration.

1. Run `notebooks/extensions/01_advanced_kpi_analysis.ipynb`.
2. Run `11_create_advanced_kpi_staging.sql` in SSMS. This missing file has been restored.
3. Run `notebooks/extensions/02_advanced_kpi_import.ipynb` with its load flag enabled, into an empty advanced staging table.
4. Run `12_create_load_advanced_kpis.sql` to create/load the KPI dimension and fact.
5. Run `13_create_advanced_kpi_views.sql`; expected nine PASS results and 474 summaries.
6. Run `notebooks/extensions/03_advanced_kpi_validation.ipynb`; expected 12 PASS comparisons.

Script 14 does **not** depend on scripts 11–13. The player profile can be built from the core event and playing-time data alone.

## Reruns and limitations

- Staging import notebooks refuse nonempty targets. A fresh run over an existing database is not intended to append duplicate source data.
- The dimensional loaders append missing natural keys, preserve existing surrogate keys, and stop if existing values conflict. They target this complete season snapshot, not general incremental updates.
- DDL can leave new empty tables if a later load transaction fails. The data-loading transaction rolls back on errors.
- `CREATE OR ALTER VIEW` scripts replace the named view definition; they do not alter facts or the base ranking when adding extension views.
- SQL 01 defaults to the database name shown above. If you change the database name, update the SQL `USE` statements as well as the Python configuration.
- Original SSMS exports are preserved under `archive/sql_exports/`, outside the main run path. Do not run that folder wholesale. Its original database export includes machine-specific file paths.
- A live SQL Server rebuild could not be executed in the packaging environment. Existing SQL validation outputs in the original notebook show successful runs; the audit separately records which steps were rerun locally.
