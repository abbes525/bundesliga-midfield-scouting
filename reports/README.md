# Validation and analysis outputs

The CSVs in this folder were generated during the packaging audit by rerunning the raw-data Python workflow. They are small, readable portfolio evidence, not substitutes for the source data.

- `raw_file_validation.csv`: per-match structural/source checks.
- `candidate_screening.csv`: independently calculated Python screening and half-season context for all 79 candidates.
- `initial_shortlist.csv`: five-player historical review list.
- `advanced_kpi_coverage.csv` and `advanced_player_summary.csv`: optional coverage-aware provider KPI outputs, separate from the core ranking.
- `packaging_pbix_reconciliation.csv`: fresh Python vs the saved PBIX Recruitment table. This is **not** a new live SQL Server execution.
- `packaging_snapshot_validation.json`: associated key/count checks.

The database validation notebooks export their own additional CSVs when run against your SQL Server. Those filenames are documented in the notebooks and are not invented here as completed test results.
