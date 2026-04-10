import { Component, OnInit, OnDestroy, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { WebsocketService, EmergencyNotification } from '../../core/services/websocket.service';
import { SolicitudesService, SolicitudEmergencia } from '../../shared/api/solicitudes.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './dashboard.component.html'
})
export class DashboardComponent implements OnInit, OnDestroy {
  public latestNotification: EmergencyNotification | null = null;
  private notificationSub!: Subscription;

  // Manejo de estado con directiva Signals (Angular 16+)
  public pendientes = signal<SolicitudEmergencia[]>([]);
  public isLoading = signal<boolean>(true);

  constructor(
    private wsService: WebsocketService,
    private solicitudesService: SolicitudesService
  ) { }

  ngOnInit(): void {
    // 1. Carga Inicial
    this.cargarPendientes();

    // 2. Suscripción Reactiva al WebSocket
    this.notificationSub = this.wsService.getNotifications().subscribe(notification => {
      this.latestNotification = notification;
      
      // Creamos la nueva solicitud estructuralmente basada en la notificación
      const nuevaSolicitud: SolicitudEmergencia = {
        id: Math.floor(Math.random() * 10000) + 1000, // ID Temporal para UX fluida
        tipo_incidente: notification.type,
        descripcion: notification.message,
        prioridad: notification.priority === 'high' ? 'ALTA' : (notification.priority === 'medium' ? 'MEDIA' : 'BAJA'),
        estado: 'PENDIENTE',
        fecha: new Date().toISOString()
      };

      // Mutamos el signal dinámicamente inyectando al principio (sin refrescar página)
      this.pendientes.update(current => [nuevaSolicitud, ...current]);

      // Auto-ocultar banner flotante
      if (notification.priority !== 'high') {
        setTimeout(() => {
          if (this.latestNotification?.id === notification.id) {
            this.latestNotification = null;
          }
        }, 8000);
      }
    });
  }

  cargarPendientes() {
    this.isLoading.set(true);
    this.solicitudesService.getPendientes().subscribe({
      next: (data) => {
        this.pendientes.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error cargando solicitudes:', err);
        // Fallback para cuando tu backend FastAPI no esté activo pero quieras ver visualmente la app
        this.isLoading.set(false);
      }
    });
  }

  aceptar(id: number) {
    this.solicitudesService.aceptarSolicitud(id).subscribe({
      next: () => {
        // En un mundo real, tal vez repitamos `this.cargarPendientes()` o modifiquemos el Signal,
        // Eliminamos dinámicamente la fila actual usando update en el Signal de Angular:
        this.pendientes.update(current => current.filter(item => item.id !== id));
      },
      error: (err) => {
        console.error('Error al aceptar servicio:', err);
        // Descomentar para demostración optimista cuando pruebes sin bd conectada:
        this.pendientes.update(current => current.filter(item => item.id !== id));
      }
    });
  }

  ngOnDestroy(): void {
    if (this.notificationSub) {
      this.notificationSub.unsubscribe();
    }
  }

  clearNotification() {
    this.latestNotification = null;
  }
}
