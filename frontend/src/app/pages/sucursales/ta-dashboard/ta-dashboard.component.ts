// src/app/pages/sucursales/ta-dashboard/ta-dashboard.component.ts
import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { NgApexchartsModule } from 'ng-apexcharts';
import type {
  ApexChart, ApexAxisChartSeries, ApexNonAxisChartSeries,
  ApexXAxis, ApexYAxis, ApexStroke, ApexFill, ApexDataLabels,
  ApexLegend, ApexPlotOptions, ApexTooltip, ApexGrid, ApexMarkers,
} from 'ng-apexcharts';

import { DashboardService } from '../../../shared/api/dashboard.service';
import type {
  Kpi2SucursalAceptacion, Kpi4TiempoLlegada, Kpi5IncidenciaItem,
  Kpi9PuntualidadItem, Kpi10PrecisionCostoItem, Kpi11MecanicoRankingItem,
} from '../../../core/models/dashboard.model';

@Component({
  selector: 'app-ta-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, NgApexchartsModule],
  templateUrl: './ta-dashboard.component.html',
  styles: [`
    .shimmer {
      background: #f6f7f8;
      background-image: linear-gradient(to right,#f6f7f8 0%,#edeef1 20%,#f6f7f8 40%,#f6f7f8 100%);
      background-repeat: no-repeat; background-size: 800px 100%;
      display: inline-block; position: relative;
      animation: shimmer-ani 1.5s infinite linear forwards;
    }
    @keyframes shimmer-ani {
      0% { background-position:-468px 0; } 100% { background-position:468px 0; }
    }
    .card-border-glow:hover { border-color: #60a5fa; }
    .animate-fade-in { animation: fadeInUp 0.5s ease forwards; }
    @keyframes fadeInUp {
      from { opacity:0; transform:translateY(16px); }
      to { opacity:1; transform:translateY(0); }
    }
  `]
})
export class TaDashboardComponent implements OnInit {

  private svc = inject(DashboardService);

  // ── Filtros ──────────────────────────────────────────────────────────────
  fechaInicio = signal('');
  fechaFin    = signal('');
  isLoading   = signal(true);

  // ── Datos KPI ─────────────────────────────────────────────────────────────
  kpi2  = signal<Kpi2SucursalAceptacion[]>([]);
  kpi4  = signal<Kpi4TiempoLlegada | null>(null);
  kpi5  = signal<Kpi5IncidenciaItem[]>([]);
  kpi9  = signal<Kpi9PuntualidadItem[]>([]);
  kpi10 = signal<Kpi10PrecisionCostoItem[]>([]);
  kpi11 = signal<Kpi11MecanicoRankingItem[]>([]);

  // ── KPI 2 — RadialBar Gauge ───────────────────────────────────────────────
  kpi2Series:  ApexNonAxisChartSeries = [0];
  kpi2Labels:  string[] = [];
  kpi2Chart:   ApexChart = {
    type: 'radialBar', height: 320, fontFamily: 'Inter, sans-serif', toolbar: { show: false },
  };
  kpi2PlotOpt: ApexPlotOptions = {
    radialBar: {
      offsetY: 0,
      startAngle: -135, endAngle: 135,
      hollow: { size: '55%', background: 'transparent' },
      track: { background: '#eff6ff', strokeWidth: '97%', margin: 5 },
      dataLabels: {
        name: { show: true, fontSize: '13px', fontWeight: 700, color: '#475569', offsetY: -10 },
        value: { show: true, fontSize: '28px', fontWeight: 900, color: '#0a1f44', offsetY: 8, formatter: (v: number) => `${v.toFixed(1)}%` },
        total: { show: true, label: 'Total respuesta', fontSize: '12px', fontWeight: 700, color: '#475569', formatter: (w: any) => {
          const avg = w.globals.series.reduce((a: number, b: number) => a + b, 0) / (w.globals.series.length || 1);
          return `${avg.toFixed(1)}%`;
        }},
      },
    },
  };
  kpi2Colors: string[] = ['#1d4ed8','#2563eb','#60a5fa','#a78bfa'];
  kpi2Legend: ApexLegend = { show: true, position: 'bottom', fontSize: '12px', fontWeight: 600 };

  // ── KPI 9 — Stacked Bar (puntualidad) ────────────────────────────────────
  kpi9Series:  ApexAxisChartSeries = [];
  kpi9Chart:   ApexChart = {
    type: 'bar', height: 180, stacked: true, stackType: '100%',
    toolbar: { show: false }, fontFamily: 'Inter, sans-serif',
  };
  kpi9Xaxis:   ApexXAxis = { categories: ['Mecánicos'], labels: { style: { fontSize: '12px', fontWeight: 600 } } };
  kpi9Colors:  string[] = ['#22c55e','#f59e0b'];
  kpi9DataL:   ApexDataLabels = { enabled: true, formatter: (v: number) => `${v.toFixed(0)}%`, style: { fontSize: '13px', fontWeight: 'bold', colors: ['#fff'] } };
  kpi9PlotOpt: ApexPlotOptions = { bar: { horizontal: true, borderRadius: 6 } };
  kpi9Legend:  ApexLegend = { show: true, position: 'bottom', fontSize: '12px', fontWeight: 600 };

  // ── KPI 4 — Grouped Bar (ETA vs Real) ────────────────────────────────────
  kpi4Series:  ApexAxisChartSeries = [];
  kpi4Chart:   ApexChart = {
    type: 'bar', height: 180, toolbar: { show: false }, fontFamily: 'Inter, sans-serif',
  };
  kpi4Xaxis:   ApexXAxis = { categories: ['Tiempo promedio (min)'], labels: { style: { fontSize: '12px', fontWeight: 600 } } };
  kpi4Colors:  string[] = ['#2563eb','#f59e0b'];
  kpi4PlotOpt: ApexPlotOptions = { bar: { horizontal: true, borderRadius: 6, dataLabels: { position: 'top' } } };
  kpi4DataL:   ApexDataLabels = { enabled: true, formatter: (v: number) => `${v?.toFixed(0)} m`, style: { fontSize: '12px', fontWeight: 'bold', colors: ['#0a1f44'] }, offsetX: 5 };
  kpi4Legend:  ApexLegend = { show: true, position: 'bottom', fontSize: '12px', fontWeight: 600 };
  kpi4Grid:    ApexGrid = { xaxis: { lines: { show: true } }, borderColor: '#e5e7eb', strokeDashArray: 4 };

  // ── KPI 5 — Donut (Tipos de Incidencia) ──────────────────────────────────
  kpi5Series:  ApexNonAxisChartSeries = [];
  kpi5Labels:  string[] = [];
  kpi5Chart:   ApexChart = {
    type: 'donut', height: 260, fontFamily: 'Inter, sans-serif', toolbar: { show: false },
  };
  kpi5Colors:  string[] = ['#1d4ed8','#2563eb','#60a5fa','#22c55e','#f59e0b','#f87171','#a78bfa'];
  kpi5PlotOpt: ApexPlotOptions = {
    pie: { donut: { size: '68%', labels: { show: true, total: { show: true, label: 'Total', fontSize: '12px', fontWeight: 700, color: '#475569',
      formatter: (w: any) => w.globals.seriesTotals.reduce((a: number, b: number) => a + b, 0).toString(),
    }}}},
  };
  kpi5DataL:   ApexDataLabels = { enabled: false };
  kpi5Legend:  ApexLegend = { show: true, position: 'bottom', fontSize: '11px', fontWeight: 600, markers: { size: 7 } };

  // ── KPI 10 — Area chart (Integridad Financiera) ───────────────────────────
  kpi10Series: ApexAxisChartSeries = [];
  kpi10Chart:  ApexChart = {
    type: 'line', height: 280, toolbar: { show: false }, fontFamily: 'Inter, sans-serif',
  };
  kpi10Xaxis:  ApexXAxis = {
    categories: [],
    labels: { show: true, style: { fontSize: '10px', colors: '#475569' }, formatter: (v: string) => `#${v}` },
  };
  kpi10Stroke: ApexStroke = { curve: 'smooth', width: [3, 2, 2], dashArray: [0, 4, 8] };
  kpi10Colors: string[] = ['#f59e0b','#1d4ed8','#22c55e'];
  kpi10DataL:  ApexDataLabels = { enabled: false };
  kpi10Legend: ApexLegend = { show: true, position: 'bottom', fontSize: '12px', fontWeight: 600 };
  kpi10Markers: ApexMarkers = { size: 4 };
  kpi10Grid:   ApexGrid = { borderColor: '#e5e7eb', strokeDashArray: 4 };
  kpi10Fill:   ApexFill = { type: ['solid','solid','solid'] };
  kpi10Tooltip: ApexTooltip = { y: { formatter: (v: number) => `Bs. ${v?.toFixed(2)}` } };

  ngOnInit(): void {
    this.cargarDatos();
  }

  aplicarFiltros(): void {
    this.cargarDatos();
  }

  private cargarDatos(): void {
    this.isLoading.set(true);
    const fi = this.fechaInicio() || undefined;
    const ff = this.fechaFin()    || undefined;

    forkJoin({
      kpi2:  this.svc.getKpi2(fi, ff),
      kpi4:  this.svc.getKpi4(fi, ff),
      kpi5:  this.svc.getKpi5(fi, ff),
      kpi9:  this.svc.getKpi9(fi, ff),
      kpi10: this.svc.getKpi10(fi, ff),
      kpi11: this.svc.getKpi11(fi, ff),
    }).subscribe({
      next: ({ kpi2, kpi4, kpi5, kpi9, kpi10, kpi11 }) => {
        this.kpi2.set(kpi2);
        this.kpi4.set(kpi4);
        this.kpi5.set(kpi5);
        this.kpi9.set(kpi9);
        this.kpi10.set(kpi10);
        this.kpi11.set(kpi11);

        this.buildKpi2Chart(kpi2);
        this.buildKpi5Chart(kpi5);
        this.buildKpi9Chart(kpi9);
        this.buildKpi4Chart(kpi4);
        this.buildKpi10Chart(kpi10);
        this.isLoading.set(false);
      },
      error: () => this.isLoading.set(false),
    });
  }

  private buildKpi2Chart(data: Kpi2SucursalAceptacion[]): void {
    this.kpi2Labels  = data.map(d => d.nombre);
    this.kpi2Series  = data.map(d => d.tasa_aceptacion_pct ?? 0);
  }

  private buildKpi5Chart(data: Kpi5IncidenciaItem[]): void {
    this.kpi5Labels = data.map(d => d.categoria_incidencia ?? 'Sin categoría');
    this.kpi5Series = data.map(d => d.total);
  }

  private buildKpi9Chart(data: Kpi9PuntualidadItem[]): void {
    const atiempo   = data.find(d => d.cumplimiento === 'A_TIEMPO');
    const atrasado  = data.find(d => d.cumplimiento === 'ATRASADO');
    this.kpi9Series = [
      { name: '✓ A Tiempo',  data: [atiempo?.cantidad  ?? 0] },
      { name: '⚠ Atrasado', data: [atrasado?.cantidad ?? 0] },
    ];
  }

  private buildKpi4Chart(data: Kpi4TiempoLlegada | null): void {
    this.kpi4Series = [
      { name: 'ETA Prometido', data: [data?.minutos_estimados_promedio ?? 0] },
      { name: 'Llegada Real',  data: [data?.minutos_reales_promedio   ?? 0] },
    ];
  }

  private buildKpi10Chart(data: Kpi10PrecisionCostoItem[]): void {
    const slice = data.slice(0, 12); // top 12 para legibilidad
    this.kpi10Xaxis  = { ...this.kpi10Xaxis, categories: slice.map(d => String(d.solicitud_id)) };
    this.kpi10Series = [
      { name: 'Estimación IA',  data: slice.map(d => d.estimacion_ia  ?? 0) },
      { name: 'Precio Puja',    data: slice.map(d => d.precio_puja    ?? 0) },
      { name: 'Costo Real',     data: slice.map(d => d.costo_real     ?? 0) },
    ];
  }

  // ── Helpers de template ───────────────────────────────────────────────────
  fmt(v: number | null | undefined, dec = 1): string {
    return v != null ? v.toFixed(dec) : '—';
  }

  deltaCls(v: number | null | undefined): string {
    if (v == null) return 'text-gray-400';
    return v <= 0 ? 'text-green-600 font-black' : 'text-amber-600 font-black';
  }

  deltaIco(v: number | null | undefined): string {
    if (v == null) return 'bx-minus';
    return v <= 0 ? 'bxs-chevron-down' : 'bxs-chevron-up';
  }

  obtenerPromedioErrorIA(): string {
    const data = this.kpi10();
    if (!data.length) return '—';
    const suma = data.reduce((s, r) => s + (r.error_pct_ia ?? 0), 0);
    return (suma / data.length).toFixed(1) + '%';
  }

  trackByEmpleado(_: number, item: Kpi11MecanicoRankingItem): number {
    return item.empleado_id;
  }
}
