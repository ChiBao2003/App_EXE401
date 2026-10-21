"""Verify canonical seeds through the real market repository/query with an in-memory Mongo cursor."""
import asyncio
import json
from pathlib import Path
from infrastructure.repositories.mongo_market_repo import MongoMarketRepository
from application.market.queries import GetAllMarketTemplatesQuery

SEEDS = Path(__file__).resolve().parents[1] / 'EXE401_Database' / 'market_templates.json'

def test_tft_templates_round_trip_through_market_query():
    seeds = json.loads(SEEDS.read_text(encoding='utf-8'))
    class Collection:
        async def rows(self):
            for i, seed in enumerate(seeds):
                yield dict(seed, _id=str(i))
        def find(self):
            return self.rows()
    class Database:
        def __getitem__(self, collection):
            assert collection == 'market_templates'
            return Collection()
    result = asyncio.run(GetAllMarketTemplatesQuery(MongoMarketRepository(Database())).execute())
    assert len(result) == 9
    anime = [template['design_json'] for template in result if template['author'] == 'AnimeStudio']
    assert len(anime) == 5
    assert [face['background'] for face in anime] == [0xFFE0, 0xFD20, 0x10A9, 0x0A85, 0x4800]
    for face in anime:
        bitmaps = [item for item in face['elements'] if item['t'] == 'bitmap']
        assert len(bitmaps) == 1
        sprite = bitmaps[0]
        assert len(sprite['v']) == ((sprite['w'] + 7) // 8) * sprite['h'] * 2
    for template in result:
        design = template['design_json']
        assert design['style'] == 'color_rgb565'
        assert 0 <= design['background'] <= 65535
        assert 1 <= len(design['elements']) <= 12
        for item in design['elements']:
            assert 0 <= item['x'] < item['x'] + item['w'] <= 320
            assert 0 <= item['y'] < item['y'] + item['h'] <= 240
            assert 0 <= item['c'] <= 65535
            assert 1 <= item['s'] <= 5
