// src/app/shared/api/reportes.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';

// ── Contratos de request ───────────────────────────────────────────────────────

export interface ReporteManualRequest {
  tabla_base:          string;
  tablas_relacionadas: string[];
  columnas:            string[];       // formato 'ENTIDAD.alias'
  filtros:             Record<string, string>;
  fecha_inicio?:       string;
  fecha_fin?:          string;
  formato:             string;
}

export interface ReporteIARequest {
  prompt:  string;
  formato: string;
}

// ── Catálogo de KPIs para el grid de tarjetas ─────────────────────────────────

export interface KpiCard {
  id:       number;
  titulo:   string;       // "nombre de negocio" del KPI
  subtitulo: string;      // descripción técnica
  icon:     string;       // clase boxicons
  accentBg: string;       // clase Tailwind para el fondo del ícono
  accentText: string;     // clase Tailwind para el color del ícono
  soloTA:   boolean;      // true = solo ADMIN_TALLER puede usarlo
}

export const KPI_CARDS: KpiCard[] = [
  { id: 1,  titulo: 'El Pulso del Negocio',      subtitulo: 'Tiempo Total de Resolución',        icon: 'bx-timer',           accentBg: 'bg-blue-50',    accentText: 'text-blue-700',   soloTA: false },
  { id: 2,  titulo: 'Índice de Responsividad',   subtitulo: 'Tasa de Conversión de SOS',          icon: 'bx-signal-5',        accentBg: 'bg-emerald-50', accentText: 'text-emerald-700', soloTA: false },
  { id: 3,  titulo: 'Fricción del Marketplace',  subtitulo: 'Tiempo de Match (Oferta Aceptada)',  icon: 'bx-transfer',        accentBg: 'bg-indigo-50',  accentText: 'text-indigo-700', soloTA: false },
  { id: 4,  titulo: 'Brecha de Expectativa',     subtitulo: 'Promesa de Llegada vs Realidad',     icon: 'bx-time-five',       accentBg: 'bg-amber-50',   accentText: 'text-amber-700',  soloTA: false },
  { id: 5,  titulo: 'Inteligencia de Mercado',   subtitulo: 'Distribución de Tipos de Falla',     icon: 'bx-pie-chart-alt-2', accentBg: 'bg-purple-50',  accentText: 'text-purple-700', soloTA: false },
  { id: 6,  titulo: 'Top Performers',            subtitulo: 'Ranking Global de Talleres',         icon: 'bx-trophy',          accentBg: 'bg-amber-50',   accentText: 'text-amber-700',  soloTA: false },
  { id: 7,  titulo: 'Expansión Territorial',     subtitulo: 'Zonas Calientes de Demanda',         icon: 'bx-map-pin',         accentBg: 'bg-red-50',     accentText: 'text-red-700',    soloTA: false },
  { id: 8,  titulo: 'Fuga de Capital',           subtitulo: 'Tasa de Cancelados por Mes',         icon: 'bx-trending-down',   accentBg: 'bg-red-50',     accentText: 'text-red-700',    soloTA: false },
  { id: 9,  titulo: 'Auditoría Operativa',       subtitulo: 'A Tiempo vs Atrasado',               icon: 'bx-user-check',      accentBg: 'bg-emerald-50', accentText: 'text-emerald-700', soloTA: false },
  { id: 10, titulo: 'Integridad Financiera',     subtitulo: 'Desviación de Estimaciones de Costo', icon: 'bx-dollar-circle',  accentBg: 'bg-blue-50',    accentText: 'text-blue-700',   soloTA: false },
  { id: 11, titulo: 'Tu Capital Humano',         subtitulo: 'Ranking de Mecánicos del Taller',    icon: 'bx-wrench',          accentBg: 'bg-indigo-50',  accentText: 'text-indigo-700', soloTA: true  },
];

// ── Catálogo de entidades para el constructor manual ──────────────────────────

export interface EntidadMeta {
  label:      string;
  columnas:   string[];
  relaciones: string[];   // entidades con las que puede hacer JOIN
}

export const ENTIDADES_META: Record<string, EntidadMeta> = {
  SOLICITUDES: {
    label:      'Solicitudes de Emergencia',
    columnas:   ['id','descripcion','estado','fecha_creacion','fecha_finalizacion','latitud','longitud','cliente_id','vehiculo_id'],
    relaciones: ['DIAGNOSTICOS','PUJAS','ASIGNACIONES','ORDENES'],
  },
  MECANICOS: {
    label:      'Mecánicos / Empleados',
    columnas:   ['id','nombre','especialidad','disponible','sucursal_id'],
    relaciones: ['ASIGNACIONES','SOLICITUDES','PAGOS'],
  },
  DIAGNOSTICOS: {
    label:      'Tipos de Servicio / Fallas',
    columnas:   ['id','problema_detectado','nivel_gravedad','costo_estimado_ia','prioridad','categoria_incidencia','fecha','solicitud_id'],
    relaciones: ['SOLICITUDES','PUJAS','PAGOS'],
  },
  ASIGNACIONES: {
    label:      'Asignaciones',
    columnas:   ['id','estado','fecha','tiempo_estimado_llegada','fecha_aceptacion','fecha_llegada','solicitud_id','empleado_id','sucursal_id'],
    relaciones: ['SOLICITUDES','MECANICOS','PUJAS'],
  },
  PUJAS: {
    label:      'Pujas / Marketplace',
    columnas:   ['id','precio_estimado','tiempo_llegada_minutos','estado','fecha','fecha_aceptacion','solicitud_id','sucursal_id'],
    relaciones: ['SOLICITUDES','ASIGNACIONES'],
  },
  ORDENES: {
    label:      'Órdenes de Trabajo',
    columnas:   ['id','estado','fecha_inicio','fecha_fin','solicitud_id','sucursal_id'],
    relaciones: ['SOLICITUDES','PAGOS'],
  },
  PAGOS: {
    label:      'Pagos y Finanzas',
    columnas:   ['id','monto_total','comision','monto_taller','estado','tipo_pago','fecha','metodo_pago','orden_id'],
    relaciones: ['ORDENES','SOLICITUDES','DIAGNOSTICOS','PUJAS','MECANICOS','SUCURSALES'],
  },
  SUCURSALES: {
    label:      'Sucursales / Talleres',
    columnas:   ['id','nombre','direccion','taller_id','taller_nombre'],
    relaciones: ['PAGOS'],
  },
};

// ── Servicio HTTP ─────────────────────────────────────────────────────────────

@Injectable({ providedIn: 'root' })
export class ReportesService {
  private http = inject(HttpClient);
  private base = `${environment.apiUrl}/reportes`;

  /** Exporta un KPI predefinido del dashboard. Respuesta: Blob (archivo binario). */
  getPredefinido(
    kpiId:   number,
    formato: string,
    fi?:     string,
    ff?:     string,
  ): Observable<Blob> {
    let params = new HttpParams().set('formato', formato);
    if (fi) params = params.set('fecha_inicio', fi);
    if (ff) params = params.set('fecha_fin',    ff);

    return this.http.get(`${this.base}/predefinido/${kpiId}`, {
      params,
      responseType: 'blob',
    });
  }

  /** Reporte dinámico por entidad + columnas + filtros. Respuesta: Blob. */
  getDinamico(req: ReporteManualRequest): Observable<Blob> {
    return this.http.post(`${this.base}/dinamico`, req, { responseType: 'blob' });
  }

  /** Reporte desde lenguaje natural (Gemini). Respuesta: Blob. */
  getIa(req: ReporteIARequest): Observable<Blob> {
    return this.http.post(`${this.base}/ia`, req, { responseType: 'blob' });
  }
}
