import asyncio
from motor.motor_asyncio import AsyncIOMotorClient

async def test():
    try:
        client = AsyncIOMotorClient('mongodb://localhost:27017', serverSelectionTimeoutMS=2000)
        info = await client.server_info()
        print('MongoDB Connection OK:', info.get('version'))
    except Exception as e:
        print('MongoDB Connection Failed:', e)

asyncio.run(test())
