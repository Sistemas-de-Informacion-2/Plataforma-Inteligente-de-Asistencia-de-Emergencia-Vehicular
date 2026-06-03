import { Component, OnInit, inject, signal, OnDestroy, NgZone } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { WebsocketService } from '../../core/services/websocket.service';
import { SolicitudesService, SolicitudEmergencia } from '../../shared/api/solicitudes.service';
import { EmpleadosService, Empleado } from '../../shared/api/empleados.service';
import { SucursalesService, Sucursal } from '../../shared/api/sucursales.service';
import { PagosService } from '../../shared/api/pagos.service';
import { PujasService } from '../../shared/api/pujas.service';
import { NotificacionesService, NotificationItem } from '../../shared/api/notificaciones.service';
import { Subscription } from 'rxjs';
import { MapSelectorComponent } from '../../shared/ui/map-selector/map-selector.component';
import { trigger, state, style, transition, animate } from '@angular/animations';
import {
  LUCIDE_ICONS, LucideAngularModule, LucideIconProvider, Bell, X, Check,
  AlertTriangle, Play, DollarSign, Clock, MapPin, CheckCircle, Volume2, Info,
  Shield, Trash2, List, Sparkles, Navigation
} from 'lucide-angular';

@Component({
  selector: 'app-despacho',
  standalone: true,
  imports: [
    CommonModule, ReactiveFormsModule, FormsModule, MapSelectorComponent,
    LucideAngularModule
  ],
  providers: [{
    provide: LUCIDE_ICONS,
    multi: true,
    useValue: new LucideIconProvider({
      Bell, X, Check, AlertTriangle, Play, DollarSign, Clock, MapPin, 
      CheckCircle, Volume2, Info, Shield, Trash2, List, Sparkles, Navigation
    })
  }],
  templateUrl: './despacho.component.html',
  animations: [
    trigger('drawerAnimation', [
      transition(':enter', [
        style({ transform: 'translateX(100%)', opacity: 0.8 }),
        animate('300ms cubic-bezier(0.16, 1, 0.3, 1)', style({ transform: 'translateX(0)', opacity: 1 }))
      ]),
      transition(':leave', [
        animate('250ms cubic-bezier(0.16, 1, 0.3, 1)', style({ transform: 'translateX(100%)', opacity: 0.8 }))
      ])
    ])
  ]
})
export class DespachoComponent implements OnInit, OnDestroy {
  private wsService = inject(WebsocketService);
  private solicitudesService = inject(SolicitudesService);
  private empleadosService = inject(EmpleadosService);
  private sucursalesService = inject(SucursalesService);
  private pagosService = inject(PagosService);
  private pujasService = inject(PujasService);
  private notificacionesService = inject(NotificacionesService);
  private ngZone = inject(NgZone);

  // Instancia única de audio
  private audioNotification = new Audio('/sounds/uber.mp3');

  // Estados reactivos (Signals)
  oportunidadesPuja = signal<any[]>([]); // Radar / SOS en ESPERANDO_PUJAS
  solicitudesEntrantes = signal<SolicitudEmergencia[]>([]); // Servicios Activos (EN_PROCESO)
  solicitudesFinalizadas = signal<SolicitudEmergencia[]>([]); // Servicios Terminados (ATENDIDO)
  sucursalActiva = signal<Sucursal | null>(null);
  mecanicosDisponibles = signal<Empleado[]>([]);

  // Historial de notificaciones y campanita
  historialNotificaciones = signal<NotificationItem[]>([]);
  noLeidasCount = signal<number>(0);
  isDrawerOpen = this.notificacionesService.isDrawerOpen;

  private wsSubscription?: Subscription;

  ngOnInit() {
    this.cargarDatosIniciales();
  }

  ngOnDestroy() {
    if (this.wsSubscription) {
      this.wsSubscription.unsubscribe();
    }
    this.wsService.disconnect();
  }

  private cargarDatosIniciales() {
    this.sucursalesService.getMisTalleres().subscribe({
      next: (talleres) => {
        if (talleres && talleres.length > 0) {
          const primerTaller = talleres[0];
          this.sucursalesService.listarSucursales(primerTaller.id).subscribe({
            next: (sucursales) => {
              if (sucursales && sucursales.length > 0) {
                const sucursal = sucursales[0];
                this.sucursalActiva.set(sucursal);
                this.cargarMecanicosDisponibles(sucursal.id);
                this.cargarSolicitudesPendientes(sucursal.id);
                this.cargarOportunidades(sucursal.id);
                this.cargarNotificaciones();
                this.iniciarWebsockets();
              }
            }
          });
        }
      }
    });
  }

  /** Carga oportunidades de puja activas (Radar) en ESPERANDO_PUJAS */
  private cargarOportunidades(sucursalId: number) {
    console.log('[Despacho] Cargando oportunidades de puja para sucursal:', sucursalId);
    this.solicitudesService.getPendientesPorSucursal(sucursalId).subscribe({
      next: (oportunidades) => {
        const opUI = oportunidades.map(o => ({
          ...o,
          precioPropuesto: null as number | null,
          yaPujado: false,
          precioPujado: null as number | null
        }));

        // Enriquecer cada oportunidad para ver si esta sucursal ya envió una puja
        opUI.forEach(op => {
          this.pujasService.listarPujas(op.id).subscribe({
            next: (res) => {
              const miPuja = res.pujas.find(p => p.sucursal_id === sucursalId);
              if (miPuja) {
                op.yaPujado = true;
                op.precioPujado = miPuja.precio_estimado;
              }
            },
            error: (err) => console.error('[Despacho] Error listando pujas de op:', op.id, err)
          });
        });

        this.oportunidadesPuja.set(opUI);
      },
      error: (err) => console.error('[Despacho] Error cargando oportunidades:', err)
    });
  }

  /** Carga servicios activos (EN_PROCESO) y finalizados (ATENDIDOS) */
  private cargarSolicitudesPendientes(sucursalId: number) {
    console.log('[Despacho] Cargando solicitudes para sucursal:', sucursalId);

    // Cargar solicitudes en proceso (ya aceptadas, pendientes de cobro)
    this.solicitudesService.getEnProcesoPorSucursal(sucursalId).subscribe({
      next: (enProceso) => {
        const enProcesoUI = enProceso.map(s => ({
          ...s,
          mecanicoSeleccionado: null as number | null,
          montoCobro: null as number | null,
          metodoPago: 'APP' as 'APP' | 'EFECTIVO' | 'QR',
          mostrandoCobro: false,
          asignando: false
        }));

        this.solicitudesEntrantes.set(enProcesoUI);
      },
      error: (err) => {
        console.error('[Despacho] Error cargando en proceso:', err);
      }
    });

    // Cargar finalizadas
    this.solicitudesService.getAtendidasPorSucursal(sucursalId).subscribe({
      next: (atendidas) => {
        this.solicitudesFinalizadas.set(atendidas);
      },
      error: (err) => console.error('[Despacho] Error cargando finalizadas:', err)
    });
  }

  private cargarMecanicosDisponibles(sucursalId: number) {
    this.empleadosService.getDisponiblesPorSucursal(sucursalId).subscribe({
      next: (mecanicos) => {
        console.log('[Despacho] Mecánicos disponibles:', mecanicos.length);
        this.mecanicosDisponibles.set(mecanicos);
      }
    });
  }

  /** Carga el historial de notificaciones desde la BD y actualiza el contador */
  cargarNotificaciones() {
    this.notificacionesService.listarNotificaciones(false, 0, 50).subscribe({
      next: (notifs) => {
        this.historialNotificaciones.set(notifs);
        this.actualizarConteoNoLeidas();
      },
      error: (err) => console.error('[Despacho] Error cargando notificaciones:', err)
    });
  }

  private actualizarConteoNoLeidas() {
    this.notificacionesService.contarNoLeidas().subscribe({
      next: (res) => {
        this.noLeidasCount.set(res.no_leidas_count);
      },
      error: (err) => console.error('[Despacho] Error contando no leídas:', err)
    });
  }

  /** WebSocket: escucha eventos en tiempo real */
  private iniciarWebsockets() {
    this.wsSubscription = this.wsService.getNotifications().subscribe({
      next: (notificacion) => {
        this.ngZone.run(() => {
          console.log('[Despacho] WebSocket recibido:', notificacion);

          // 1. Reproducir sonido de notificación
          this.reproducirSonido();

          // 2. Refrescar notificaciones persistentes en la BD
          this.cargarNotificaciones();

          const sucursalId = this.sucursalActiva()?.id;

          // 3. Manejar el flujo de eventos inDrive
          if (notificacion.type === 'NUEVO_SOS_ZONA' && notificacion.solicitud_id) {
            // Evitar duplicar
            const yaExiste = this.oportunidadesPuja().find(s => s.id === notificacion.solicitud_id);
            if (yaExiste) return;

            // Obtener detalle completo de la emergencia
            this.solicitudesService.getDetalleSolicitud(notificacion.solicitud_id).subscribe({
              next: (solicitud) => {
                this.oportunidadesPuja.update(lista => [
                  { ...solicitud, precioPropuesto: null, yaPujado: false, precioPujado: null },
                  ...lista
                ]);
              },
              error: (err) => console.error('[Despacho] Error obteniendo detalle de SOS:', err)
            });
          }
          else if (notificacion.type === 'PUJA_GANADORA' && notificacion.solicitud_id) {
            // ¡Ganamos la puja! El cliente nos eligió
            // Remover del Radar
            this.oportunidadesPuja.update(lista => lista.filter(o => o.id !== notificacion.solicitud_id));

            // Cargar a Servicios Activos
            if (sucursalId) {
              this.cargarSolicitudesPendientes(sucursalId);
              this.cargarMecanicosDisponibles(sucursalId);
            }
          }
          else if (notificacion.type === 'PUJA_RECHAZADA' && notificacion.solicitud_id) {
            // El cliente eligió otra puja
            // Remover del Radar
            this.oportunidadesPuja.update(lista => lista.filter(o => o.id !== notificacion.solicitud_id));
          }
          else if (notificacion.type === 'PUJA_RECHAZADA_CLIENTE' && notificacion.solicitud_id) {
            // El cliente rechazó específicamente nuestra oferta actual
            Swal.fire({
              toast: true,
              position: 'top-end',
              showConfirmButton: false,
              timer: 5000,
              icon: 'info',
              title: 'Oferta rechazada',
              text: `El cliente rechazó tu oferta para la solicitud #${notificacion.solicitud_id}. ¡Puedes intentar con un precio más bajo!`
            });
            this.reproducirSonido();
            
            // Reiniciar el estado local de la puja para permitir enviar una nueva
            this.oportunidadesPuja.update(lista => lista.map(o => {
              if (o.id === notificacion.solicitud_id) {
                return { ...o, yaPujado: false, precioPujado: null, precioPropuesto: null };
              }
              return o;
            }));
          }
          else if ((notificacion.type === 'SOLICITUD_CANCELADA' || notificacion.type === 'SOS_CERRADO') && notificacion.solicitud_id) {
            // El cliente canceló la solicitud o eligió otro taller (SOS_CERRADO)
            this.oportunidadesPuja.update(lista => lista.filter(o => o.id !== notificacion.solicitud_id));
            if (notificacion.type === 'SOLICITUD_CANCELADA') {
              Swal.fire({
                toast: true,
                position: 'top-end',
                showConfirmButton: false,
                timer: 4000,
                icon: 'warning',
                title: 'Solicitud Cancelada',
                text: `El cliente canceló la solicitud #${notificacion.solicitud_id}.`
              });
            }
          }
          else if (notificacion.type === 'MECANICO_RECHAZO' && notificacion.solicitud_id) {
            // El mecánico rechazó o se acabó el tiempo límite
            // Forzar actualización inmediata del estado en la memoria local
            this.solicitudesEntrantes.update(lista => lista.map(s => {
              if (s.id === notificacion.solicitud_id) {
                return { ...s, estado: 'OFERTA_ACEPTADA', asignando: false, mecanicoSeleccionado: null };
              }
              return s;
            }));

            if (sucursalId) {
              this.cargarSolicitudesPendientes(sucursalId);
              this.cargarMecanicosDisponibles(sucursalId);
            }
            
            Swal.fire({
              icon: 'warning',
              title: 'Asignación Rechazada / Sin Respuesta',
              text: notificacion['mensaje'] || 'El mecánico no pudo atender la asignación.',
              confirmButtonText: 'Entendido'
            });
          }
          else if ((notificacion.type === 'MECANICO_EN_CAMINO' || notificacion.type === 'MECANICO_EN_SITIO') && notificacion.solicitud_id) {
            // El mecánico aceptó y está en camino (o en sitio)
            this.solicitudesEntrantes.update(lista => lista.map(s => {
              if (s.id === notificacion.solicitud_id) {
                return { ...s, estado: notificacion.type === 'MECANICO_EN_CAMINO' ? 'EN_CAMINO' : 'EN_SITIO', asignando: false };
              }
              return s;
            }));
            Swal.fire({
              toast: true,
              position: 'top-end',
              showConfirmButton: false,
              timer: 4000,
              icon: 'success',
              title: 'Mecánico en acción',
              text: notificacion['mensaje'] || 'El mecánico aceptó la asignación y ya está trabajando.'
            });
          }
        });
      }
    });
  }

  /**
   * Reproduce el sonido de notificación de forma no bloqueante
   */
  private reproducirSonido() {
    try {
      this.audioNotification.currentTime = 0;
      this.audioNotification.play().catch(e => console.warn('[Despacho] Audio play bloqueado por el navegador:', e));
    } catch (err) {
      console.warn('[Despacho] Error reproduciendo audio:', err);
    }
  }

  /** Envía una puja de precio para una oportunidad */
  enviarPuja(solicitud: any) {
    const sucursalId = this.sucursalActiva()?.id;
    if (!sucursalId || !solicitud.id) return;

    if (!solicitud.precioPropuesto || solicitud.precioPropuesto <= 0) {
      Swal.fire('Atención', 'Por favor ingresa un precio de puja válido.', 'warning');
      return;
    }

    this.pujasService.crearPuja(solicitud.id, solicitud.precioPropuesto).subscribe({
      next: () => {
        solicitud.yaPujado = true;
        solicitud.precioPujado = solicitud.precioPropuesto;
        // Refrescar campanita
        this.cargarNotificaciones();
      },
      error: (err) => {
        console.error('[Despacho] Error al enviar puja:', err);
        Swal.fire('Error', err.error?.detail || 'No se pudo enviar la puja en este momento.', 'error');
      }
    });
  }

  /** Acciones del Drawer de notificaciones */
  toggleDrawer() {
    this.notificacionesService.isDrawerOpen.update(v => !v);
  }

  marcarComoLeida(notif: NotificationItem) {
    if (notif.leido) return;
    this.notificacionesService.marcarComoLeida(notif.id).subscribe({
      next: () => {
        this.historialNotificaciones.update(lista =>
          lista.map(n => n.id === notif.id ? { ...n, leido: true } : n)
        );
        this.actualizarConteoNoLeidas();
      },
      error: (err) => console.error('[Despacho] Error marcando notificación:', err)
    });
  }

  marcarTodasComoLeidas() {
    this.notificacionesService.marcarTodasComoLeidas().subscribe({
      next: () => {
        this.historialNotificaciones.update(lista =>
          lista.map(n => ({ ...n, leido: true }))
        );
        this.actualizarConteoNoLeidas();
      },
      error: (err) => console.error('[Despacho] Error marcando todas:', err)
    });
  }

  /** Asigna un técnico del taller al servicio activo (EN_PROCESO) */
  asignarTecnico(solicitud: SolicitudEmergencia) {
    const sucursalId = this.sucursalActiva()?.id;
    if (!sucursalId || !solicitud.id) return;

    const payload = {
      empleado_id: solicitud.mecanicoSeleccionado ?? null
    };

    console.log('[Despacho] Asignando mecánico al servicio:', solicitud.id, payload);
    solicitud.asignando = true;

    this.solicitudesService.asignarMecanico(sucursalId, solicitud.id, payload).subscribe({
      next: () => {
        console.log('[Despacho] Mecánico asignado exitosamente');
        Swal.fire({
          toast: true,
          position: 'top-end',
          showConfirmButton: false,
          timer: 3000,
          icon: 'success',
          title: 'Asignado',
          text: 'Técnico asignado correctamente.'
        });
        
        // Optimistic UI update
        solicitud.estado = payload.empleado_id ? 'ESPERANDO_CONFIRMACION_MECANICO' : 'EN_CAMINO';
        solicitud.asignando = false;
        
        this.cargarSolicitudesPendientes(sucursalId);
      },
      error: (err) => {
        solicitud.asignando = false;
        console.error('[Despacho] Error al asignar técnico:', err);
        Swal.fire('Error', err.error?.detail || 'Hubo un error al asignar al técnico.', 'error');
      }
    });
  }

  /** UI de Cobro final*/
  mostrarModalCobro(solicitud: SolicitudEmergencia) {
    this.solicitudesEntrantes.update(solicitudes =>
      solicitudes.map(s =>
        s.id === solicitud.id ? { ...s, mostrandoCobro: true, metodoPago: 'APP' } : s
      )
    );
  }

  cobrarServicio(solicitud: any) {
    if (!solicitud.montoCobro || solicitud.montoCobro <= 0) {
      Swal.fire('Atención', 'Por favor ingresa un monto válido.', 'warning');
      return;
    }

    if (!solicitud.id) return;

    const metodo = 'APP'; // Forzamos siempre APP para que el cliente elija el método en su dispositivo

    this.pagosService.crearPago(solicitud.id, solicitud.montoCobro, metodo).subscribe({
      next: (res) => {
        Swal.fire({
          title: 'Cobro Enviado',
          text: 'Cobro enviado al cliente exitosamente. Esperando que el cliente realice el pago desde la aplicación.',
          icon: 'success',
          confirmButtonText: 'Entendido'
        });

        // Mover a finalizadas
        const solicitudActualizada = { ...solicitud, estado: 'ATENDIDO' };
        this.solicitudesFinalizadas.update(lista => [solicitudActualizada, ...lista]);

        // Remover de la vista de activos
        this.solicitudesEntrantes.update(solicitudes =>
          solicitudes.filter(s => s.id !== solicitud.id)
        );
      },
      error: (err) => {
        console.error('Error al crear pago:', err);
        Swal.fire('Error', 'No se pudo procesar el cobro.', 'error');
      }
    });
  }
}
