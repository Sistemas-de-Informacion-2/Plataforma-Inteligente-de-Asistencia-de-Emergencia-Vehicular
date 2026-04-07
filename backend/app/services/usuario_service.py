"""
Servicio: Usuario.
Registro, consulta y actualización de usuarios.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.usuario import Usuario, UsuarioPerfil
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.usuario import UsuarioCreate, UsuarioUpdate


class UsuarioService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = UsuarioRepository(session)

    # ── Registro ──────────────────────────────────────────────

    async def registrar(self, data: UsuarioCreate) -> Usuario:
        """
        Registra un nuevo usuario.
        - Valida unicidad de email y CI
        - Hashea la contraseña
        - Crea el perfil si se proporciona
        """
        # Validar unicidad
        if await self.repo.email_exists(data.email):
            raise ValueError(f"El email '{data.email}' ya está registrado")
        if await self.repo.ci_exists(data.ci):
            raise ValueError(f"El CI '{data.ci}' ya está registrado")

        # Preparar datos del usuario
        user_data = data.model_dump(exclude={"perfil"})
        user_data["password"] = hash_password(user_data["password"])

        # Crear usuario
        usuario = await self.repo.create(user_data)

        # Crear perfil si se proporcionó
        if data.perfil:
            perfil_data = data.perfil.model_dump()
            perfil_data["usuario_id"] = usuario.id
            perfil = UsuarioPerfil(**perfil_data)
            self.session.add(perfil)
            await self.session.flush()
            await self.session.refresh(usuario)

        return usuario

    # ── Consultas ─────────────────────────────────────────────

    async def obtener_por_id(self, usuario_id: int) -> Usuario | None:
        return await self.repo.get_by_id(usuario_id)

    async def obtener_con_perfil(self, usuario_id: int) -> Usuario | None:
        return await self.repo.get_with_perfil(usuario_id)

    async def obtener_con_roles(self, usuario_id: int) -> Usuario | None:
        return await self.repo.get_with_roles(usuario_id)

    async def obtener_por_email(self, email: str) -> Usuario | None:
        return await self.repo.get_by_email(email)

    async def listar(self, skip: int = 0, limit: int = 100) -> list[Usuario]:
        return list(await self.repo.get_all(skip=skip, limit=limit))

    # ── Actualización ─────────────────────────────────────────

    async def actualizar(self, usuario_id: int, data: UsuarioUpdate) -> Usuario | None:
        update_data = data.model_dump(exclude_unset=True)
        if not update_data:
            return await self.repo.get_by_id(usuario_id)
        return await self.repo.update(usuario_id, update_data)

    # ── Eliminación ───────────────────────────────────────────

    async def eliminar(self, usuario_id: int) -> bool:
        return await self.repo.delete(usuario_id)
