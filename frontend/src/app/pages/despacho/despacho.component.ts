import { Component, OnInit, inject, signal, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { WebsocketService, EmergencyNotification } from '../../core/services/websocket.service';
import { SolicitudesService, SolicitudEmergencia } from '../../shared/api/solicitudes.service';
import { EmpleadosService, Empleado } from '../../shared/api/empleados.service';
import { SucursalesService, Sucursal } from '../../shared/api/sucursales.service';
import { PagosService } from '../../shared/api/pagos.service';
import { Subscription } from 'rxjs';
import { MapSelectorComponent } from '../../shared/ui/map-selector/map-selector.component';

@Component({
  selector: 'app-despacho',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, FormsModule, MapSelectorComponent],
  templateUrl: './despacho.component.html'
})
export class DespachoComponent implements OnInit, OnDestroy {
  private wsService = inject(WebsocketService);
  private solicitudesService = inject(SolicitudesService);
  private empleadosService = inject(EmpleadosService);
  private sucursalesService = inject(SucursalesService);
  private pagosService = inject(PagosService);

  solicitudesEntrantes = signal<SolicitudEmergencia[]>([]);
  solicitudesFinalizadas = signal<SolicitudEmergencia[]>([]);
  sucursalActiva = signal<Sucursal | null>(null);
  mecanicosDisponibles = signal<Empleado[]>([]);

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
                this.iniciarWebsockets();
              }
            }
          });
        }
      }
    });
  }

  /**
   * Carga inicial: solicitudes pendientes + en proceso (para mostrar UI de cobro).
   */
  private cargarSolicitudesPendientes(sucursalId: number) {
    console.log('[Despacho] Cargando solicitudes para sucursal:', sucursalId);
    
    // Cargar pendientes
    this.solicitudesService.getPendientesPorSucursal(sucursalId).subscribe({
      next: (pendientes) => {
        const pendientesUI = pendientes.map(s => ({ 
          ...s, 
          mecanicoSeleccionado: null as number | null,
          montoCobro: null as number | null,
          mostrandoCobro: false
        }));

        // Cargar en proceso (ya aceptadas, pendientes de cobro)
        this.solicitudesService.getEnProcesoPorSucursal(sucursalId).subscribe({
          next: (enProceso) => {
            const enProcesoUI = enProceso.map(s => ({
              ...s,
              mecanicoSeleccionado: null as number | null,
              montoCobro: null as number | null,
              metodoPago: 'APP' as 'APP' | 'EFECTIVO' | 'QR',
              mostrandoCobro: false
            }));
            
            console.log(`[Despacho] ${pendientesUI.length} pendientes + ${enProcesoUI.length} en proceso`);
            this.solicitudesEntrantes.set([...pendientesUI, ...enProcesoUI]);
          },
          error: (err) => {
            console.error('[Despacho] Error cargando en proceso:', err);
            // Al menos mostrar las pendientes
            this.solicitudesEntrantes.set(pendientesUI);
          }
        });
      },
      error: (err) => {
        console.error('[Despacho] Error cargando solicitudes pendientes:', err);
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

  private iniciarWebsockets() {
    this.wsSubscription = this.wsService.getNotifications().subscribe({
      next: (notificacion) => {
        console.log('[Despacho] WebSocket recibido:', notificacion);

        if (notificacion.type === 'NUEVA_SOLICITUD_EMERGENCIA' && notificacion.solicitud_id) {
          // Evitar duplicados
          const yaExiste = this.solicitudesEntrantes().find(s => s.id === notificacion.solicitud_id);
          if (yaExiste) {
            console.log('[Despacho] Solicitud duplicada ignorada:', notificacion.solicitud_id);
            return;
          }

          // Obtener el detalle completo de la solicitud
          console.log('[Despacho] Obteniendo detalle de solicitud:', notificacion.solicitud_id);
          this.solicitudesService.getDetalleSolicitud(notificacion.solicitud_id).subscribe({
            next: (solicitud) => {
              console.log('[Despacho] Detalle de solicitud recibido:', solicitud);
              this.solicitudesEntrantes.update(lista => [
                { ...solicitud, mecanicoSeleccionado: null, montoCobro: null, metodoPago: 'APP', mostrandoCobro: false },
                ...lista
              ]);
            },
            error: (err) => {
              console.error('[Despacho] Error obteniendo detalle de solicitud:', err);
            }
          });
        }
      }
    });
  }

  responder(solicitud: SolicitudEmergencia, aceptar: boolean) {
    const sucursalId = this.sucursalActiva()?.id;
    if (!sucursalId || !solicitud.id) return;

    // Si no hay mecánicos o el admin seleccionó "Yo mismo", empleado_id es null
    const payload = {
      aceptar,
      empleado_id: aceptar ? (solicitud.mecanicoSeleccionado ?? null) : null
    };

    console.log('[Despacho] Respondiendo solicitud:', solicitud.id, payload);

    this.solicitudesService.responderSolicitud(sucursalId, solicitud.id, payload).subscribe({
      next: () => {
        console.log('[Despacho] Respuesta exitosa para solicitud:', solicitud.id);
        if (aceptar) {
          this.cargarMecanicosDisponibles(sucursalId);
          // Actualizar estado de forma INMUTABLE para que el signal detecte el cambio
          this.solicitudesEntrantes.update(solicitudes =>
            solicitudes.map(s => 
              s.id === solicitud.id 
                ? { ...s, estado: 'EN_PROCESO', mostrandoCobro: false } 
                : s
            )
          );
        } else {
           this.solicitudesEntrantes.update(solicitudes =>
            solicitudes.filter(s => s.id !== solicitud.id)
          );
        }
      },
      error: (err) => {
        console.error('[Despacho] Error al responder solicitud:', err);
        alert('Hubo un error al procesar la respuesta.');
      }
    });
  }

  mostrarModalCobro(solicitud: SolicitudEmergencia) {
    // Actualizar inmutablemente para trigger del signal
    this.solicitudesEntrantes.update(solicitudes =>
      solicitudes.map(s => 
        s.id === solicitud.id ? { ...s, mostrandoCobro: true, metodoPago: 'APP' } : s
      )
    );
  }

  cobrarServicio(solicitud: any) {
    if (!solicitud.montoCobro || solicitud.montoCobro <= 0) {
      alert('Por favor ingresa un monto válido.');
      return;
    }

    if (!solicitud.id) return;

    const metodo = solicitud.metodoPago || 'APP';

    this.pagosService.crearPago(solicitud.id, solicitud.montoCobro, metodo).subscribe({
      next: (res) => {
        if (metodo === 'APP') {
          alert(`Cobro enviado al cliente exitosamente. Comisión a retener: Bs. ${res.comision}`);
        } else {
          alert(`Cobro registrado en ${metodo}. La comisión de Bs. ${res.comision} fue añadida a tu deuda.`);
          // Actualizar deuda global inmediatamente
          this.pagosService.deudaGlobal.update(d => d + res.comision);
        }
        
        // Mover a finalizadas y actualizar estado local
        const solicitudActualizada = { ...solicitud, estado: 'ATENDIDO' };
        this.solicitudesFinalizadas.update(lista => [solicitudActualizada, ...lista]);
        
        // Remover de la vista de despacho
        this.solicitudesEntrantes.update(solicitudes =>
          solicitudes.filter(s => s.id !== solicitud.id)
        );
      },
      error: (err) => {
        console.error('Error al crear pago:', err);
        alert('No se pudo procesar el cobro.');
      }
    });
  }
}
