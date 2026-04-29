# backend/app/services/storage_service.py
"""
Servicio de almacenamiento de archivos.
Abstrae la lógica de guardado para poder migrar de Local → S3 sin tocar endpoints.
"""
from abc import ABC, abstractmethod
from fastapi import UploadFile
from pathlib import Path
import uuid


class StorageService(ABC):
    """Interfaz base — cualquier implementación (Local, S3, GCS) hereda de aquí."""

    @abstractmethod
    async def upload_file(self, file: UploadFile, directory: str) -> str:
        """
        Sube un archivo y retorna su URL relativa / pública.
        """
        ...

    @abstractmethod
    async def upload_file_with_path(self, file: UploadFile, directory: str) -> tuple[str, str]:
        """
        Sube un archivo y retorna (url_relativa, ruta_fisica_absoluta).
        Necesario para pipelines que requieren acceso al archivo en disco
        (ej: Whisper, Gemini).
        """
        ...


class LocalStorageService(StorageService):
    """Implementación local — guarda archivos en disco."""

    def __init__(self, base_dir: str = "uploads"):
        self.base_dir = Path(base_dir)
        self.base_dir.mkdir(parents=True, exist_ok=True)

    async def _save(self, file: UploadFile, directory: str) -> tuple[str, str]:
        """Lógica interna de guardado. Retorna (url_relativa, ruta_fisica)."""
        target_dir = self.base_dir / directory
        target_dir.mkdir(parents=True, exist_ok=True)

        ext = file.filename.split(".")[-1] if file.filename else "bin"
        unique_name = f"{uuid.uuid4().hex}.{ext}"
        file_path = target_dir / unique_name

        # Leer contenido completo con la API async de UploadFile
        await file.seek(0)
        content = await file.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content)

        url_relativa = f"/{self.base_dir.name}/{directory}/{unique_name}"
        ruta_fisica = str(file_path.resolve())

        return url_relativa, ruta_fisica

    async def upload_file(self, file: UploadFile, directory: str) -> str:
        url_relativa, _ = await self._save(file, directory)
        return url_relativa

    async def upload_file_with_path(self, file: UploadFile, directory: str) -> tuple[str, str]:
        return await self._save(file, directory)


# ── Instancia global y dependency injection ──────────────────
storage_service = LocalStorageService()


def get_storage_service() -> StorageService:
    """FastAPI Dependency — inyecta el StorageService activo."""
    return storage_service
