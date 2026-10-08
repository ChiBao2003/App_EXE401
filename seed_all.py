import os
import json
from pymongo import MongoClient

def seed_db():
    print("Connecting to MongoDB...")
    client = MongoClient("mongodb://localhost:27017/")
    db = client["Pomodoro_App"]
    
    db_folder = r"c:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\EXE401_Database"
    
    collections = {
        "market_templates.json": "market_templates",
        "schedules.json": "schedules",
        "firmwares.json": "firmwares",
        "users.json": "users"
    }
    
    for filename, collection_name in collections.items():
        filepath = os.path.join(db_folder, filename)
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                data = json.load(f)
                
            collection = db[collection_name]
            collection.delete_many({}) # Clear existing data
            if data:
                if isinstance(data, list):
                    collection.insert_many(data)
                else:
                    collection.insert_one(data)
            print(f"✅ Seeded {len(data)} items into {collection_name}")
        else:
            print(f"❌ File not found: {filepath}")

if __name__ == "__main__":
    seed_db()
