"""
Paquete de modelos SQLAlchemy.
Importa TODOS los modelos para que:
1. Alembic los detecte al importar Base.metadata
2. Las relaciones entre tablas se resuelvan correctamente
"""
from app.core.database import Base  # noqa: F401

# Modelos de autenticación y usuarios
from app.models.usuario import Usuario, UsuarioPerfil  # noqa: F401
from app.models.rol import Rol, Permiso, RolPermiso, UsuarioRol  # noqa: F401
from app.models.admin import Admin  # noqa: F401
from app.models.empleado import Empleado  # noqa: F401

# Modelos de negocio
from app.models.vehiculo import Vehiculo  # noqa: F401
from app.models.taller import Taller, Sucursal  # noqa: F401
from app.models.servicio import Servicio, SucursalServicio  # noqa: F401
from app.models.solicitud_emergencia import SolicitudEmergencia  # noqa: F401
from app.models.evidencia import Evidencia  # noqa: F401
from app.models.diagnostico_ia import DiagnosticoIA  # noqa: F401
from app.models.orden_trabajo import OrdenTrabajo, DetalleOrden  # noqa: F401
from app.models.asignacion import Asignacion  # noqa: F401
from app.models.puja import Puja  # noqa: F401
from app.models.pago import Pago, MetodoPago  # noqa: F401
from app.models.notificacion import Notificacion  # noqa: F401
from app.models.resena import ResenaForo  # noqa: F401
from app.models.sos_notificacion_sucursal import SosNotificacionSucursal  # noqa: F401
