// src/app/shared/api/dashboard.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../../environments/environment';
import {
  Kpi1TiempoEspera, Kpi2SucursalAceptacion, Kpi3TiempoAsignacion,
  Kpi4TiempoLlegada, Kpi5IncidenciaItem, Kpi6TallerEficiente,
  Kpi7MapaCalorItem, Kpi8CanceladosMes, Kpi9PuntualidadItem,
  Kpi10PrecisionCostoItem, Kpi11MecanicoRankingItem,
} from '../../core/models/dashboard.model';

@Injectable({ providedIn: 'root' })
export class DashboardService {
  private http = inject(HttpClient);
  private base = `${environment.apiUrl}/dashboard`;

  private params(fi?: string, ff?: string): HttpParams {
    let p = new HttpParams();
    if (fi) p = p.set('fecha_inicio', fi);
    if (ff) p = p.set('fecha_fin', ff);
    return p;
  }

  getKpi1(fi?: string, ff?: string): Observable<Kpi1TiempoEspera> {
    return this.http.get<Kpi1TiempoEspera>(`${this.base}/kpi1-tiempo-espera`, { params: this.params(fi, ff) });
  }

  getKpi2(fi?: string, ff?: string): Observable<Kpi2SucursalAceptacion[]> {
    return this.http.get<Kpi2SucursalAceptacion[]>(`${this.base}/kpi2-tasa-aceptacion`, { params: this.params(fi, ff) });
  }

  getKpi3(fi?: string, ff?: string): Observable<Kpi3TiempoAsignacion> {
    return this.http.get<Kpi3TiempoAsignacion>(`${this.base}/kpi3-tiempo-asignacion`, { params: this.params(fi, ff) });
  }

  getKpi4(fi?: string, ff?: string): Observable<Kpi4TiempoLlegada> {
    return this.http.get<Kpi4TiempoLlegada>(`${this.base}/kpi4-tiempo-llegada`, { params: this.params(fi, ff) });
  }

  getKpi5(fi?: string, ff?: string): Observable<Kpi5IncidenciaItem[]> {
    return this.http.get<Kpi5IncidenciaItem[]>(`${this.base}/kpi5-tipos-incidencia`, { params: this.params(fi, ff) });
  }

  getKpi6(fi?: string, ff?: string): Observable<Kpi6TallerEficiente[]> {
    return this.http.get<Kpi6TallerEficiente[]>(`${this.base}/kpi6-ranking-talleres`, { params: this.params(fi, ff) });
  }

  getKpi7(fi?: string, ff?: string): Observable<Kpi7MapaCalorItem[]> {
    return this.http.get<Kpi7MapaCalorItem[]>(`${this.base}/kpi7-mapa-calor`, { params: this.params(fi, ff) });
  }

  getKpi8(fi?: string, ff?: string): Observable<Kpi8CanceladosMes[]> {
    return this.http.get<Kpi8CanceladosMes[]>(`${this.base}/kpi8-tasa-cancelados`, { params: this.params(fi, ff) });
  }

  getKpi9(fi?: string, ff?: string): Observable<Kpi9PuntualidadItem[]> {
    return this.http.get<Kpi9PuntualidadItem[]>(`${this.base}/kpi9-puntualidad`, { params: this.params(fi, ff) });
  }

  getKpi10(fi?: string, ff?: string): Observable<Kpi10PrecisionCostoItem[]> {
    return this.http.get<Kpi10PrecisionCostoItem[]>(`${this.base}/kpi10-precision-costos`, { params: this.params(fi, ff) });
  }

  getKpi11(fi?: string, ff?: string): Observable<Kpi11MecanicoRankingItem[]> {
    return this.http.get<Kpi11MecanicoRankingItem[]>(`${this.base}/kpi11-ranking-mecanicos`, { params: this.params(fi, ff) });
  }
}
