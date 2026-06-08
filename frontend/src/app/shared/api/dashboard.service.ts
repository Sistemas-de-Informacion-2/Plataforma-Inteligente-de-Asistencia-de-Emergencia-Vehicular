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
  Kpi12LiquidezMarketplace, Kpi13IngresosComisiones, Kpi14HorasPico,
  Kpi15RetencionClientes, Kpi16EmbudoAbandono, Kpi17WinRatePujas,
  Kpi18EvolucionIngresos, Kpi19TopVehiculos, Kpi20TiemposOperativosMecanico
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

  getKpi12(fi?: string, ff?: string): Observable<Kpi12LiquidezMarketplace> {
    return this.http.get<Kpi12LiquidezMarketplace>(`${this.base}/kpi12-liquidez-marketplace`, { params: this.params(fi, ff) });
  }

  getKpi13(fi?: string, ff?: string): Observable<Kpi13IngresosComisiones[]> {
    return this.http.get<Kpi13IngresosComisiones[]>(`${this.base}/kpi13-ingresos-comisiones`, { params: this.params(fi, ff) });
  }

  getKpi14(fi?: string, ff?: string): Observable<Kpi14HorasPico[]> {
    return this.http.get<Kpi14HorasPico[]>(`${this.base}/kpi14-horas-pico`, { params: this.params(fi, ff) });
  }

  getKpi15(fi?: string, ff?: string): Observable<Kpi15RetencionClientes[]> {
    return this.http.get<Kpi15RetencionClientes[]>(`${this.base}/kpi15-retencion-clientes`, { params: this.params(fi, ff) });
  }

  getKpi16(fi?: string, ff?: string): Observable<Kpi16EmbudoAbandono[]> {
    return this.http.get<Kpi16EmbudoAbandono[]>(`${this.base}/kpi16-embudo-abandono`, { params: this.params(fi, ff) });
  }

  getKpi17(fi?: string, ff?: string): Observable<Kpi17WinRatePujas[]> {
    return this.http.get<Kpi17WinRatePujas[]>(`${this.base}/kpi17-win-rate-pujas`, { params: this.params(fi, ff) });
  }

  getKpi18(fi?: string, ff?: string): Observable<Kpi18EvolucionIngresos[]> {
    return this.http.get<Kpi18EvolucionIngresos[]>(`${this.base}/kpi18-evolucion-ingresos`, { params: this.params(fi, ff) });
  }

  getKpi19(fi?: string, ff?: string): Observable<Kpi19TopVehiculos[]> {
    return this.http.get<Kpi19TopVehiculos[]>(`${this.base}/kpi19-top-vehiculos`, { params: this.params(fi, ff) });
  }

  getKpi20(fi?: string, ff?: string): Observable<Kpi20TiemposOperativosMecanico[]> {
    return this.http.get<Kpi20TiemposOperativosMecanico[]>(`${this.base}/kpi20-tiempos-operativos`, { params: this.params(fi, ff) });
  }
}
