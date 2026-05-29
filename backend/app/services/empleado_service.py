# backend/app/services/empleado_service.py
"""
Servicio: Empleado (Mecanico).
CRUD + gestión de disponibilidad + creación transaccional Usuario→Empleado.
"""

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.elements import WKTElement

from app.core.security import hash_password
from app.models.empleado import Empleado
from app.models.usuario import Usuario
from app.models.rol import Rol, UsuarioRol
from app.repositories.empleado_repository import EmpleadoRepository
from app.repositories.usuario_repository import UsuarioRepository
from app.schemas.empleado import EmpleadoCreate, EmpleadoCreateFull, EmpleadoUpdate


class EmpleadoService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = EmpleadoRepository(session)
        self.usuario_repo = UsuarioRepository(session)

    # ── Crear empleado simple (sin usuario) ───────────────────
    async def crear(self, data: EmpleadoCreate) -> Empleado:
        empleado_data = data.model_dump()

        # Generar geometría PostGIS si hay coordenadas
        if data.latitud is not None and data.longitud is not None:
            empleado_data["ubicacion"] = WKTElement(
                f"POINT({data.longitud} {data.latitud})", srid=4326
            )

        return await self.repo.create(empleado_data)

    # ── Crear Usuario + Empleado en una sola transacción ──────
    async def crear_con_usuario(self, data: EmpleadoCreateFull) -> Empleado:
        """
        Transacción atómica:
          1. Validar unicidad email/CI
          2. Hash password → crear Usuario
          3. Asignar rol MECANICO
          4. Crear Empleado vinculado al usuario y sucursal
          5. flush() entre pasos, commit() lo hace get_db()
        """
        # ── Paso 1: Validar unicidad ──────────────────────────
        if await self.usuario_repo.email_exists(data.email):
            raise ValueError(f"El email '{data.email}' ya está registrado")
        if await self.usuario_repo.ci_exists(data.ci):
            raise ValueError(f"El CI '{data.ci}' ya está registrado")

        # ── Paso 2: Crear Usuario ─────────────────────────────
        hashed_pw = hash_password(data.password)
        usuario = Usuario(
            nombre=data.nombre,
            email=data.email,
            password=hashed_pw,
            ci=data.ci,
            telefono=data.telefono,
        )
        self.session.add(usuario)
        await self.session.flush()  # Obtener usuario.id

        # ── Paso 3: Asignar rol MECANICO ───────────────────────
        stmt = select(Rol).where(Rol.nombre == "MECANICO")
        result = await self.session.execute(stmt)
        rol_tecnico = result.scalar_one_or_none()

        if not rol_tecnico:
            raise ValueError("Rol 'MECANICO' no encontrado en la base de datos. Ejecute el seeder.")

        usuario_rol = UsuarioRol(
            usuario_id=usuario.id,
            rol_id=rol_tecnico.id,
        )
        self.session.add(usuario_rol)
        await self.session.flush()

        # ── Paso 4: Crear Empleado ────────────────────────────
        empleado_data = {
            "usuario_id": usuario.id,
            "sucursal_id": data.sucursal_id,
            "especialidad": data.especialidad,
            "disponible": True,
            "latitud": data.latitud,
            "longitud": data.longitud,
        }

        # Generar geometría PostGIS si hay coordenadas
        if data.latitud is not None and data.longitud is not None:
            empleado_data["ubicacion"] = WKTElement(
                f"POINT({data.longitud} {data.latitud})", srid=4326
            )

        empleado = await self.repo.create(empleado_data)
        return empleado

    # ── Consultas ─────────────────────────────────────────────
    async def obtener_por_id(self, empleado_id: int) -> Empleado | None:
        return await self.repo.get_by_id(empleado_id)

    async def obtener_por_usuario(self, usuario_id: int) -> Empleado | None:
        return await self.repo.get_by_usuario(usuario_id)

    async def listar(self, skip: int = 0, limit: int = 100) -> list[Empleado]:
        return list(await self.repo.get_all(skip=skip, limit=limit))

    async def listar_por_admin(
        self, admin_id: int, skip: int = 0, limit: int = 100
    ) -> list[Empleado]:
        """Retorna solo empleados del taller del admin (Tenant Isolation)."""
        return list(await self.repo.get_by_admin(admin_id, skip=skip, limit=limit))

    async def obtener_por_id_scoped(
        self, empleado_id: int, admin_id: int
    ) -> Empleado | None:
        """
        Obtiene un empleado por ID verificando que pertenezca al admin.
        Devuelve None si no le pertenece (para lanzar 403 en el endpoint).
        """
        return await self.repo.get_by_id_scoped(empleado_id, admin_id)

    async def listar_por_sucursal(
        self,
        sucursal_id: int,
        solo_disponibles: bool = False,
    ) -> list[Empleado]:
        return list(
            await self.repo.get_by_sucursal(
                sucursal_id, solo_disponibles=solo_disponibles
            )
        )

    async def listar_disponibles(
        self,
        sucursal_id: int | None = None,
        especialidad: str | None = None,
    ) -> list[Empleado]:
        return list(
            await self.repo.get_disponibles(
                sucursal_id=sucursal_id, especialidad=especialidad
            )
        )

    # ── Actualización ─────────────────────────────────────────
    async def actualizar(
        self, empleado_id: int, data: EmpleadoUpdate
    ) -> Empleado | None:
        update_data = data.model_dump(exclude_unset=True)

        # Si se actualizan coordenadas, regenerar la geometría PostGIS
        if "latitud" in update_data or "longitud" in update_data:
            empleado = await self.repo.get_by_id(empleado_id)
            if empleado:
                lat = update_data.get("latitud", empleado.latitud)
                lng = update_data.get("longitud", empleado.longitud)
                if lat is not None and lng is not None:
                    update_data["ubicacion"] = WKTElement(
                        f"POINT({lng} {lat})", srid=4326
                    )

        if not update_data:
            return await self.repo.get_by_id(empleado_id)
        return await self.repo.update(empleado_id, update_data)

    async def cambiar_disponibilidad(
        self, empleado_id: int, disponible: bool
    ) -> Empleado | None:
        """Atajo: marcar un técnico como disponible/no disponible."""
        return await self.repo.update(empleado_id, {"disponible": disponible})

    async def actualizar_ubicacion(
        self, empleado_id: int, latitud: float, longitud: float
    ) -> Empleado | None:
        """Actualiza la ubicación GPS del técnico en movimiento (Float + PostGIS)."""
        update_data = {
            "latitud": latitud,
            "longitud": longitud,
            "ubicacion": WKTElement(
                f"POINT({longitud} {latitud})", srid=4326
            ),
        }
        return await self.repo.update(empleado_id, update_data)

    # ── Eliminación (Soft-Delete con Ofuscación) ────────────────────
    async def eliminar(self, empleado_id: int) -> bool:
        """
        Baja de un empleado (técnico):
          1. Soft-delete del registro Empleado (es_eliminado=True)
          2. Retirar el rol TECNICO del UsuarioRol
          3. Ofuscar email y CI para liberar restricciones UNIQUE
          4. Soft-delete del Usuario base
        
        Esto obliga al usuario a registrarse de nuevo si desea volver
        a usar la plataforma (ej. para ser dueño de su propio taller),
        lo cual es la vía más directa de "ascenso".
        """
        from sqlalchemy import delete as sa_delete
        from sqlalchemy import select
        from datetime import datetime

        # Obtener el empleado
        empleado = await self.repo.get_by_id(empleado_id)
        if not empleado:
            return False

        usuario_id = empleado.usuario_id

        # ── Paso 1: Soft-delete del Empleado ──────────────────
        await self.repo.delete(empleado_id)

        # ── Paso 2: Retirar rol TECNICO ───────────────────────
        stmt_rol = select(Rol).where(Rol.nombre == "TECNICO")
        result = await self.session.execute(stmt_rol)
        rol_tecnico = result.scalar_one_or_none()

        if rol_tecnico:
            stmt_del = sa_delete(UsuarioRol).where(
                UsuarioRol.usuario_id == usuario_id,
                UsuarioRol.rol_id == rol_tecnico.id,
            )
            await self.session.execute(stmt_del)

        # ── Paso 3: Ofuscar credenciales del Usuario ──────────
        usuario = await self.usuario_repo.get_by_id(usuario_id)
        if usuario:
            # Usamos el ID del usuario (único) para no exceder el límite de VARCHAR(20) del CI
            email_base = usuario.email if usuario.email else "none"
            ci_base = usuario.ci if usuario.ci else "none"
            
            # Formato: d28_email@... (truncado al límite de la DB si es necesario)
            email_ofuscado = f"d{usuario.id}_{email_base}"[:150]
            ci_ofuscado = f"d{usuario.id}_{ci_base}"[:20]

            await self.usuario_repo.update(usuario_id, {
                "email": email_ofuscado,
                "ci": ci_ofuscado,
            })

        # ── Paso 4: Soft-delete del Usuario ───────────────────
        await self.usuario_repo.delete(usuario_id)
        await self.session.flush()
        return True

