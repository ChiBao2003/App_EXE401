"""Upsert bundled TFT samples without clearing community templates or other collections."""
import json
import os
from pathlib import Path
from pymongo import MongoClient


def seed_tft_market():
    source = Path(__file__).resolve().parents[1] / 'EXE401_Database' / 'market_templates.json'
    templates = json.loads(source.read_text(encoding='utf-8'))
    with MongoClient(os.getenv('MONGO_URI', 'mongodb://localhost:27017'), serverSelectionTimeoutMS=5000) as client:
        collection = client[os.getenv('MONGO_DB_NAME', 'Pomodoro_App')]['market_templates']
        for index, template in enumerate(templates):
            key = f'tft_builtin_{index}'
            # Match previous sample titles on the first migration as well.
            title = template['design_json']['title']
            previous_title = 'E-Ink Heritage Calendar' if title == 'Heritage Calendar' else title
            collection.update_one(
                {'$or': [{'seed_key': key}, {'design_json.title': previous_title, 'author': template['author'].replace('TftHeritage', 'EinkHeritage')}]},
                {'$set': dict(template, seed_key=key)}, upsert=True,
            )
        print(f'TFT templates available: {collection.count_documents({"seed_key": {"$in": [f"tft_builtin_{i}" for i in range(len(templates))]}})}')


if __name__ == '__main__':
    seed_tft_market()
