from pydantic import BaseModel

class FirmwareModel(BaseModel):
    version: str
    release_date: str
    file_url: str
    description: str
