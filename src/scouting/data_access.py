"""Cache provider JSON locally; do not rely on notebook execution history."""
import json
from pathlib import Path
from urllib.request import urlopen
import pandas as pd
from .config import RAW_DIR, IMPECT_BASE_URL, ITERATION_ID

def load_or_download_json(url, destination):
    """Return (JSON object, status); write downloads atomically into the cache."""
    destination = Path(destination)
    if destination.exists():
        with destination.open(encoding='utf-8') as handle:
            return json.load(handle), 'cached'
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(url, timeout=60) as response:
        data = json.load(response)
    temporary = destination.with_suffix(destination.suffix + '.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')
    temporary.replace(destination)
    return data, 'downloaded'

def metadata(relative_path):
    """Cache small metadata files separately from the season event files."""
    return load_or_download_json(
        f'{IMPECT_BASE_URL}/{relative_path}',
        RAW_DIR / 'metadata' / Path(relative_path).name,
    )[0]

def load_metadata_context():
    """Create the explicit common inputs required by the season notebooks."""
    impect_matches_data = metadata(f'matches/matches_{ITERATION_ID}.json')
    impect_matches = pd.json_normalize(impect_matches_data)
    if not impect_matches['iterationId'].eq(ITERATION_ID).all():
        raise ValueError('Unexpected iteration in match metadata.')
    available_matches = impect_matches.loc[impect_matches['available'].eq(True)].drop_duplicates('id').copy()
    if len(available_matches) != 306 or available_matches['id'].nunique() != 306:
        raise ValueError('This project expects the 306-match Bundesliga 2023/24 snapshot.')
    squads_data = metadata(f'squads/squads_{ITERATION_ID}.json')
    players_data = metadata(f'players/players_{ITERATION_ID}.json')
    squads = pd.json_normalize(squads_data)
    players = pd.json_normalize(players_data)
    player_lookup = players[['id', 'commonname']].rename(columns={'id':'player.id','commonname':'player_name'})
    squad_lookup = squads[['id','name']].rename(columns={'id':'squadId','name':'team_name'})
    if player_lookup['player.id'].duplicated().any() or squad_lookup['squadId'].duplicated().any():
        raise ValueError('Lookup IDs must be unique.')
    example_match_id = int(available_matches.sort_values(['scheduledDate','id']).iloc[0]['id'])
    return dict(iteration_id=ITERATION_ID, impect_matches_data=impect_matches_data,
                impect_matches=impect_matches, available_matches=available_matches,
                squads_data=squads_data, squads=squads, players_data=players_data,
                players=players, player_lookup=player_lookup, squad_lookup=squad_lookup,
                example_match_id=example_match_id)
