# Local data

The lightweight project download excludes raw JSON and generated checkpoints.

To reuse your existing downloaded season, copy the **impect folder** from your original project into:

`data/raw/impect/`

It should contain `events/`, `player_kpis/`, `events_kpis/` and the download manifest. The setup helper downloads the small player/team/match metadata files into `data/raw/impect/metadata/` if absent. You do not need to download the full season again when your 306 event and 306 player-KPI files are already cached.

If you do not copy your cache, notebook 01 downloads the missing season files. They occupy approximately 1.1 GB uncompressed. `docs/source_manifest.csv` records the checksums of the uploaded raw snapshot for traceability.

Generated `core_analysis.pkl` and optional `advanced_analysis.pkl` go in `data/processed/`. These locally generated checkpoints preserve Pandas types across independent notebooks; both raw data and checkpoints are ignored by Git.
