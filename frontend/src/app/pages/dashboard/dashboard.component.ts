import { Component, OnInit, OnDestroy, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { WebsocketService, EmergencyNotification } from '../../core/services/websocket.service';
import { SolicitudesService, SolicitudEmergencia } from '../../shared/api/solicitudes.service';
import { Subscription } from 'rxjs';
import { MapSelectorComponent } from '../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, MapSelectorComponent],
  templateUrl: './dashboard.component.html'
})
export class DashboardComponent implements OnInit, OnDestroy {
  public latestNotification: EmergencyNotification | null = null;
  private notificationSub!: Subscription;

  public pendientes = signal<SolicitudEmergencia[]>([]);
  public isLoading = signal<boolean>(true);

  // Modal State
  public solicitudSeleccionada = signal<SolicitudEmergencia | null>(null);

  constructor(
    private wsService: WebsocketService,
    private solicitudesService: SolicitudesService
  ) { }

  ngOnInit(): void {
    this.cargarPendientes();

    // Mock Websocket para Inyección Reactiva (con métricas IA)
    this.notificationSub = this.wsService.getNotifications().subscribe(notification => {
      this.latestNotification = notification;
      
      const nuevaSolicitud: SolicitudEmergencia = {
        id: Math.floor(Math.random() * 10000) + 1000,
        tipo_incidente: notification.type,
        descripcion: notification.message,
        prioridad: notification.priority === 'high' ? 'ALTA' : (notification.priority === 'medium' ? 'MEDIA' : 'BAJA'),
        estado: 'PENDIENTE',
        latitud: -17.7833 + (Math.random() - 0.5) * 0.05,
        longitud: -63.1821 + (Math.random() - 0.5) * 0.05,
        fecha: new Date().toISOString(),
        // Mock de nuestro motor de clasificación multimodal:
        resumen_ia: 'Se confirma auto inmovilizado en vía pública (batería descargada detectada por transcripción de audio). Posible intervención rápida sin remolque.',
        clasificacion_ia: 'Falla Eléctrica (Confianza 94%)'
      };

      this.pendientes.update(current => [nuevaSolicitud, ...current]);

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
        // Fallback demo Visual para ver el diseño IA sin BD conectada
        this.pendientes.set([{
            id: 2041, tipo_incidente: 'Accidente Leve', descripcion: 'Golpe en el parachoques con auto de atrás.',
            prioridad: 'MEDIA', estado: 'PENDIENTE', latitud: -17.76, longitud: -63.18, 
            resumen_ia: 'Daño moderado en chasis trasero. Auto no requiere remolque urgente. (Basado en 3 fotos analizadas).',
            clasificacion_ia: 'Chapa/Pintura (Confianza 89%)'
        }]);
        this.isLoading.set(false);
      }
    });
  }

  abrirMapa(solicitud: SolicitudEmergencia) {
    const solMapa = { ...solicitud };
    if (!solMapa.latitud || !solMapa.longitud) {
      solMapa.latitud = -17.7833 + (Math.random() - 0.5) * 0.05;
      solMapa.longitud = -63.1821 + (Math.random() - 0.5) * 0.05;
    }
    this.solicitudSeleccionada.set(solMapa);
  }

  cerrarModal() {
    this.solicitudSeleccionada.set(null);
  }

  aceptar(id: number) {
    this.solicitudesService.aceptarSolicitud(id).subscribe({
      next: () => {
        this.pendientes.update(current => current.filter(item => item.id !== id));
      },
      error: (err) => {
        console.error('Error al aceptar:', err);
        this.pendientes.update(current => current.filter(item => item.id !== id)); // Optimista
      }
    });
  }

  rechazar(id: number) {
    this.solicitudesService.rechazarSolicitud(id).subscribe({
      next: () => {
        this.pendientes.update(current => current.filter(item => item.id !== id));
      },
      error: (err) => {
        console.error('Error al rechazar:', err);
        this.pendientes.update(current => current.filter(item => item.id !== id)); // Optimista
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
