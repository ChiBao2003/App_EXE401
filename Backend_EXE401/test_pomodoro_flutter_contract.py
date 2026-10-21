"""Validate actual SppService test output using the real FastAPI request model.

Run Flutter spp_service_test.dart first to produce build/pomodoro_audit_payloads.json.
MongoDB is mocked; no production data or credentials are used.
"""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import AsyncMock, MagicMock

from fastapi import FastAPI
from httpx import AsyncClient, ASGITransport
from pydantic import ValidationError

from api.v1.pomodoro_router import router, PomodoroSyncPayload, HardwareData, PhoneData
from core.database import get_database
from core.security import get_current_user_id


class FlutterContractTest(unittest.IsolatedAsyncioTestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).parents[1] / 'Frontend_EXE401/build/pomodoro_audit_payloads.json'
        cls.payloads = json.loads(path.read_text(encoding='utf-8'))
        assert len(cls.payloads) == 2, 'Run the Flutter payload tests first'

    def test_exact_field_names_types_and_false(self):
        for raw in self.payloads:
            model = PomodoroSyncPayload.model_validate(raw, strict=True)
            self.assertEqual(set(raw), set(PomodoroSyncPayload.model_fields))
            self.assertEqual(set(raw['hardware_data']), set(HardwareData.model_fields))
            self.assertEqual(set(raw['phone_data']), set(PhoneData.model_fields))
            self.assertEqual(model.model_dump(), raw)
        self.assertEqual({p['hardware_data']['completed'] for p in self.payloads}, {True, False})

    def test_required_fields_match_backend(self):
        for field in ['user_id', 'hardware_data', 'phone_data']:
            raw = dict(self.payloads[0])
            del raw[field]
            with self.assertRaises(ValidationError):
                PomodoroSyncPayload.model_validate(raw)

    async def request(self, raw, failure=None, existing=None):
        app = FastAPI()
        app.include_router(router, prefix='/api/v1/pomodoro')
        collection = MagicMock()
        collection.update_one = AsyncMock(
            return_value=SimpleNamespace(upserted_id='saved-document'), side_effect=failure)
        collection.find_one = AsyncMock(return_value=existing)
        db = MagicMock()
        db.__getitem__.return_value = collection
        app.dependency_overrides[get_database] = lambda: db
        app.dependency_overrides[get_current_user_id] = lambda: 'user-a'
        async with AsyncClient(transport=ASGITransport(app=app), base_url='http://test') as client:
            result = await client.post('/api/v1/pomodoro/sync', json=raw)
        return result, collection

    async def test_both_completed_states_are_written_before_success(self):
        for raw in self.payloads:
            result, collection = await self.request(raw)
            self.assertEqual(result.status_code, 200, result.text)
            self.assertEqual(result.json()['status'], 'ok')
            written = collection.update_one.call_args_list[0].args[1]['$setOnInsert']
            self.assertEqual(written['hardware_data'], raw['hardware_data'])
            self.assertEqual(written['phone_data'], raw['phone_data'])
            self.assertEqual(written['hardware_session_id'], raw['session_id'])

    async def test_db_failure_does_not_confirm_persistence(self):
        for error, expected in [(RuntimeError('write failed'), 500), (TimeoutError('timeout'), 503)]:
            result, _ = await self.request(self.payloads[0], failure=error)
            self.assertEqual(result.status_code, expected, result.text)
            self.assertNotEqual(result.json().get('status'), 'ok')

    async def test_duplicate_only_succeeds_when_existing_record_is_found(self):
        result, _ = await self.request(self.payloads[0], failure=RuntimeError('duplicate'), existing={
            '_id': 'existing-document', 'user_id': 'user-a',
        })
        self.assertEqual(result.status_code, 200, result.text)
        self.assertEqual(result.json()['session_id'], 'existing-document')


if __name__ == '__main__':
    unittest.main(verbosity=2)
