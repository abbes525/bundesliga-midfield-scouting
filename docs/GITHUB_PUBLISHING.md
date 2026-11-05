# Prepare the repository for GitHub

1. Extract the organized archive into a new folder. Keep your original project as a backup.
2. Copy your existing `data/raw/impect/` cache into the matching location in the new folder if you want to continue locally without downloading it again.
3. Read the audit report and open the renamed PBIX. Check the final Player Profile bar charts in Power BI Desktop.
4. Add actual report screenshots to `reports/screenshots/` and link them in the README when ready.
5. From the organized project root, run:

```bash
python scripts/check_structure.py
git init -b main
git add .
git status --short
```

Before committing, confirm raw JSON, `.pkl` checkpoints, the `.venv` folder and `archive/` are absent from the staged list. The included `.gitignore` excludes them. The project PBIX and small derived report CSVs are intentionally included.

```bash
git commit -m "Add Bundesliga midfield scouting portfolio project"
```

Create an empty repository in your own GitHub account, then use GitHub's displayed commands to add that repository as the remote and push. No remote repository has been created or published by this packaging work.

Suggested repository name: `bundesliga-midfield-scouting`.

Suggested description: `Bundesliga 2023/24 midfielder screening and player profiling with Python, SQL Server, and Power BI.`

The archived original files remain in the downloadable package for your reference but are ignored by Git. Provider data and your own code have separate rights; choose a code license deliberately rather than implying that the IMPECT data inherits it.
