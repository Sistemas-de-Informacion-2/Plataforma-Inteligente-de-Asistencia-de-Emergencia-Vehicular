# backend/app/services/usuario_service.py
"""
Servicio: Usuario.
Registro, consulta y actualización de usuarios.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import hash_password
from app.models.usuario import Usuario, UsuarioPerfil
from app.models.rol import Rol, UsuarioRol
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.usuario import UsuarioCreate, UsuarioUpdate
from sqlalchemy import select


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

        # Asignar rol por defecto (CLIENTE)
        stmt_rol = select(Rol).where(Rol.nombre == 'CLIENTE')
        res_rol = await self.session.execute(stmt_rol)
        rol_cliente = res_rol.scalar_one_or_none()
        
        if rol_cliente:
            nuevo_usuario_rol = UsuarioRol(usuario_id=usuario.id, rol_id=rol_cliente.id)
            self.session.add(nuevo_usuario_rol)
            await self.session.flush()

        # Cargar explícitamente la relación perfil (o None) para evitar el error MissingGreenlet
        return await self.obtener_con_perfil(usuario.id)

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

    async def actualizar_perfil_completo(self, usuario_id: int, data) -> Usuario | None:
        """
        Actualiza tanto los campos del Usuario (nombre, telefono) 
        como los del UsuarioPerfil (segundo_nombre, apellidos, fechas, etc).
        """
        usuario = await self.repo.get_with_perfil(usuario_id)
        if not usuario:
            return None

        update_data = data.model_dump(exclude_unset=True)
        
        # 1. Update campos en el modelo Usuario
        usuario_fields = ["nombre", "telefono"]
        ha_cambiado_usuario = False
        for field in usuario_fields:
            if field in update_data:
                setattr(usuario, field, update_data[field])
                ha_cambiado_usuario = True
        
        # 2. Update campos en el modelo UsuarioPerfil
        perfil_fields = ["segundo_nombre", "apellido_paterno", "apellido_materno", "foto_perfil", "fecha_nacimiento"]
        if not usuario.perfil:
            # Crear si no existe
            perfil = UsuarioPerfil(usuario_id=usuario_id)
            for field in perfil_fields:
                if field in update_data:
                    setattr(perfil, field, update_data[field])
            self.session.add(perfil)
        else:
            for field in perfil_fields:
                if field in update_data:
                    setattr(usuario.perfil, field, update_data[field])

        await self.session.flush()
        # En lugar de refresh, obtenemos el objeto limpio con sus relaciones cargadas
        return await self.obtener_con_perfil(usuario_id)
