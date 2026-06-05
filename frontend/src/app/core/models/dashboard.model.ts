// src/app/core/models/dashboard.model.ts

export interface Kpi1TiempoEspera {
  minutos_promedio: number | null;
  total_finalizadas: number;
}

export interface Kpi2SucursalAceptacion {
  sucursal_id: number;
  nombre: string;
  sos_recibidos: number;
  sos_respondidos: number;
  tasa_aceptacion_pct: number | null;
}

export interface Kpi3TiempoAsignacion {
  minutos_promedio_asignacion: number | null;
  total_medidos: number;
}

export interface Kpi4TiempoLlegada {
  minutos_reales_promedio: number | null;
  minutos_estimados_promedio: number | null;
  delta_promedio_min: number | null;
  total_medidos: number;
}

export interface Kpi5IncidenciaItem {
  categoria_incidencia: string | null;
  total: number;
  porcentaje: number;
}

export interface Kpi6TallerEficiente {
  sucursal_id: number;
  nombre: string;
  rating_promedio: number | null;
  pct_completado: number | null;
  delta_puntualidad_min: number | null;
  sos_recibidos: number;
  tasa_respuesta_pct: number | null;
}

export interface Kpi7MapaCalorItem {
  latitud: number;
  longitud: number;
  densidad: number;
}

export interface Kpi8CanceladosMes {
  mes: string;
  canceladas: number;
  total: number;
  tasa_cancelacion_pct: number;
}

export interface Kpi9PuntualidadItem {
  cumplimiento: string;
  cantidad: number;
  porcentaje: number;
}

export interface Kpi10PrecisionCostoItem {
  solicitud_id: number;
  estimacion_ia: number | null;
  precio_puja: number | null;
  costo_real: number | null;
  delta_vs_ia: number | null;
  delta_vs_puja: number | null;
  error_pct_ia: number | null;
}

export interface Kpi11MecanicoRankingItem {
  empleado_id: number;
  nombre: string;
  sucursal_nombre: string;
  asignaciones_completadas: number;
  tiempo_promedio_llegada_min: number | null;
  tiempo_promedio_eta_min: number | null;
  delta_promedio_min: number | null;
}
