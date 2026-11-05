# Project audit and organization report

Audit date: **5 November 2026**. Input: the uploaded `football-no8-recruitment bundsliga.zip`. This report separates file completeness, changes made, local recomputation and checks that still need the user's Windows applications.

## Findings and fixes

| Finding in the uploaded ZIP | Resolution |
|---|---|
| SQL steps 01–10 and 12–14 were present; **11 was absent** | Added `sql/11_create_advanced_kpi_staging.sql`, matching the seven-column payload used by the existing importer. |
| `ggg.ipynb` contained 79 code cells and no markdown cells | Mapped all 78 substantive code cells into eight titled notebooks with explanations before each analytical step. The installation magic moved to requirements. |
| `ggg.ipynb` lived at the root while its path check required a `notebooks/` directory that was absent | Created the notebook structure and replaced that assumption with repository-root discovery. |
| The final iteration was selected by taking the first catalogue entry | Pinned iteration **743** explicitly. |
| Python initial ranking used raw floating-point scores, while the final reconciliation later rounded scores to six decimals | Applied the six-decimal rank rule at score creation, before club/half-season review. Scores remain unrounded. This preserves the validated SQL/PBIX tie for Xhaka and Schlager. |
| Later cells depended on variables created in a previous long notebook session | Added explicit metadata bootstrap and named local checkpoints; every notebook can start in a fresh kernel. |
| SQL loaders were interleaved with analysis and imports could be accidentally rerun | Separated computational, write and validation notebooks. Added an explicit write flag; existing nonempty-table guards remain. |
| SQL connection settings were repeated | Centralized connection construction and environment-configurable server/database settings. |
| No dependency or Git-ignore files | Added requirements, pyproject, .gitignore and an environment-variable example. |
| No cached player/team/match/KPI metadata files in the archive | Added a reusable small-metadata cache helper; downloaded the five metadata files during testing. The raw cache remains local. |
| Root README and SQL README described the older ten-script/five-page state and an importer not yet packaged | Rewrote both to describe the real 01–14 SQL package, six report pages and current runnable Python steps. |
| Main SQL files and redundant SSMS exports occupied the same working area | Kept numbered SQL scripts in `sql/`; preserved all 21 original reference exports under ignored `archive/sql_exports/`. |
| Two PBIX files included an old report | Renamed the current v3 report to `powerbi/bundesliga_midfield_scouting.pbix` without changing bytes; preserved the older file in the archive. |
| No final report screenshots | Added a documented screenshots destination. Actual final Desktop screenshots remain to be exported. |

## Input completeness

- **306/306** season event exports present.
- **306/306** season player-KPI/playing-time exports present.
- **17/17** targeted event-KPI exports present.
- **612** rows in the supplied download manifest; its recorded statuses were 606 downloaded and six cached, with no failed entries.
- Original notebook, both supplied PBIX files, main README and SQL files were readable; original notebook had no saved exception outputs.
- `docs/source_manifest.csv` records 630 original raw/cache files including the manifest, plus five newly cached metadata files, with byte counts and SHA-256 hashes.

The raw cache is approximately 1.1 GB uncompressed. It is not a missing deliverable in the lightweight organized ZIP: it is deliberately excluded, with copying/downloading instructions in `data/README.md`.

## Tests actually rerun during this audit

### Fresh Python computation from the supplied raw cache

Executed every code cell in:

1. `notebooks/01_data_preparation_and_screening.ipynb`.
2. `notebooks/exploration/02_impect_data_walkthrough.ipynb`.
3. `notebooks/extensions/01_advanced_kpi_analysis.ipynb`.

Each started in a fresh process and used its own setup cell. Generated outputs and execution counts are retained for these three notebooks. The other notebooks remain unexecuted rather than carrying misleading old outputs.

The core run reproduced:

| Check | Result |
|---|---:|
| Raw-file validation | 306 PASS |
| Season event rows | 939,200 |
| Playing-time rows | 10,577 |
| Eligible candidates | 79 |
| Both-half minutes rule | 58 |
| Shortlist | Schlager, Xhaka, Stach, Can, Stöger |
| Passing-focus tie | Schlager and Xhaka both rank 1 |

The optional advanced run reproduced **12,690 payload rows**, **474 summaries** and **two** event-supplied values. It preserved absent values and signed pxT contributions.

### Comparison with the saved report model

Inspected the actual data embedded in the uploaded PBIX, not just its screenshots.

- Compared **29 numerical outputs for all 79 candidates** against the freshly executed Python analysis: **zero mismatches** at the documented tolerances. Ranks and counts used exact agreement; floating quantities used small absolute tolerances.
- Matched **all 71,092 profile pass natural keys** (match + event ID) to the independently selected raw midfield pass events.
- Confirmed **79 profile summary rows**.
- Compared **474 advanced summary keys** plus 11 count/status/numerical columns with the fresh Python extension: **PASS**, including missing values.

Evidence: `reports/packaging_pbix_reconciliation.csv`, `packaging_snapshot_validation.json` and `packaging_advanced_pbix_validation.json`. These are comparisons with a **saved PBIX snapshot**, not live SQL Server queries.

### Structural checks

- All eight notebooks pass notebook-format validation; every code cell parses as Python.
- Shared Python modules and entry-point scripts parse successfully.
- Numbered SQL scripts **01–14** are present exactly once each.
- Existing numbered SQL scripts are preserved byte-for-byte; only the missing 11 is added.
- The current report PBIX is renamed byte-for-byte, without modifying its model or report definition in this task.
- Original notebook and original SQL exports are retained unchanged in `archive/`.
- The archive excludes raw JSON, local checkpoints, Python caches, virtual environments and Git internals.

Test environment: Python 3.12.14, Pandas 2.2.3 and NumPy 2.3.5 for the computational notebooks. SQL inspection used the previously uploaded saved report snapshot.

## Tests not rerun here

- No live SQL Server was available. SQL DDL execution, loading and fresh SQL-to-Python validation must run on the user's SQL Server. The existing notebook and supplied results record earlier successful SQL checks, but this audit does not represent a newly executed empty-database build.
- The optional historical alternative-provider notebook was preserved and syntax-checked, not re-executed against its live catalogue.
- Power BI Desktop was unavailable. Final native bar-chart rendering, slicer interactions, refresh and navigation still need a Desktop check. No synthetic screenshots are included as evidence.
- Download recovery was exercised through the existing cache and new metadata helper; a complete remote re-download of all 612 season files was not required or claimed.

## How to use the organized copy

1. Extract the organized ZIP into a **new** folder; keep the original archive.
2. Copy your existing `data/raw/impect/` into the new folder's matching path if you want to work locally without re-downloading the season.
3. Install requirements and read the main notebook/README.
4. For the existing populated database, use validation; do not rerun staging imports or delete stored data.
5. Before publishing, inspect the final PBIX in Desktop and add actual screenshots if desired. Use Git so `.gitignore` excludes local data and archived drafts.

The optional advanced work is preserved and documented separately. The main portfolio path remains three notebooks and the six-page report.
