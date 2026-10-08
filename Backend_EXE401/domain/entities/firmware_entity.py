"""
domain/entities/firmware_entity.py - Tầng Domain
Pure Python entity cho Firmware OTA.
"""
from dataclasses import dataclass
from typing import Optional
from datetime import datetime


@dataclass
class FirmwareEntity:
    """Entity đại diện cho một bản cập nhật Firmware."""
    version: str           # "1.0.0"
    download_url: str
    changelog: str
    release_date: Optional[datetime] = None
    id: Optional[str] = None
