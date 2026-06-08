// src/app/pages/super-admin/sa-dashboard/sa-dashboard.component.ts
import {
  Component, OnInit, OnDestroy, AfterViewInit,
  signal, inject, ViewChild, ElementRef, PLATFORM_ID, Inject,
} from '@angular/core';
import { CommonModule, isPlatformBrowser } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { forkJoin } from 'rxjs';
import { NgApexchartsModule } from 'ng-apexcharts';
import type {
  ApexChart, ApexAxisChartSeries, ApexNonAxisChartSeries,
  ApexXAxis, ApexStroke, ApexFill, ApexDataLabels,
  ApexLegend, ApexPlotOptions, ApexTooltip, ApexGrid,
} from 'ng-apexcharts';
import * as L from 'leaflet';

import { DashboardService } from '../../../shared/api/dashboard.service';
import type {
  Kpi1TiempoEspera, Kpi5IncidenciaItem,
  Kpi6TallerEficiente, Kpi7MapaCalorItem, Kpi8CanceladosMes,
  Kpi12LiquidezMarketplace, Kpi13IngresosComisiones, Kpi14HorasPico,
  Kpi15RetencionClientes, Kpi16EmbudoAbandono
} from '../../../core/models/dashboard.model';

@Component({
  selector: 'app-sa-dashboard',
  standalone: true,
  imports: [CommonModule, FormsModule, NgApexchartsModule],
  templateUrl: './sa-dashboard.component.html',
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
    #heatmap-container { height: 380px; width: 100%; border-radius: 1.5rem; overflow: hidden; z-index: 1; }
    .animate-fade-in { animation: fadeInUp 0.5s ease forwards; }
    @keyframes fadeInUp {
      from { opacity:0; transform:translateY(16px); }
      to { opacity:1; transform:translateY(0); }
    }
  `]
})
export class SaDashboardComponent implements OnInit, AfterViewInit, OnDestroy {

  private svc = inject(DashboardService);
  private isBrowser: boolean;

  @ViewChild('heatmapEl') heatmapEl!: ElementRef<HTMLDivElement>;
  private heatmap!: L.Map;
  private heatCircles: L.CircleMarker[] = [];

  // ── Filtros ──────────────────────────────────────────────────────────────
  fechaInicio = signal('');
  fechaFin    = signal('');

  // ── Estado ───────────────────────────────────────────────────────────────
  isLoading = signal(true);

  // ── Datos KPI ─────────────────────────────────────────────────────────────
  kpi1  = signal<Kpi1TiempoEspera | null>(null);
  kpi5  = signal<Kpi5IncidenciaItem[]>([]);
  kpi6  = signal<Kpi6TallerEficiente[]>([]);
  kpi7  = signal<Kpi7MapaCalorItem[]>([]);
  kpi8  = signal<Kpi8CanceladosMes[]>([]);
  kpi12 = signal<Kpi12LiquidezMarketplace | null>(null);
  kpi13 = signal<Kpi13IngresosComisiones[]>([]);
  kpi14 = signal<Kpi14HorasPico[]>([]);
  kpi15 = signal<Kpi15RetencionClientes[]>([]);
  kpi16 = signal<Kpi16EmbudoAbandono[]>([]);

  // ── Chart options ─────────────────────────────────────────────────────────
  // KPI8 — Line chart
  kpi8Series:   ApexAxisChartSeries = [{ name: 'Tasa cancelación %', data: [] }];
  kpi8Chart:    ApexChart    = { type: 'area', height: 280, toolbar: { show: false }, fontFamily: 'Inter, sans-serif', sparkline: { enabled: false } };
  kpi8Xaxis:    ApexXAxis   = { categories: [], labels: { style: { colors: '#475569', fontSize: '11px', fontWeight: 600 } } };
  kpi8Stroke:   ApexStroke  = { curve: 'smooth', width: 3 };
  kpi8Fill:     ApexFill    = { type: 'gradient', gradient: { shadeIntensity: 1, opacityFrom: 0.35, opacityTo: 0.02, stops: [0, 90, 100] } };
  kpi8Colors:   string[]    = ['#f59e0b'];
  kpi8Grid:     ApexGrid    = { borderColor: '#e5e7eb', strokeDashArray: 4 };
  kpi8DataL:    ApexDataLabels = { enabled: false };
  kpi8Tooltip:  ApexTooltip = { y: { formatter: (v: number) => `${v.toFixed(1)}%` } };

  // KPI5 — Donut chart
  kpi5Series:  ApexNonAxisChartSeries = [];
  kpi5Chart:   ApexChart    = { type: 'donut', height: 280, fontFamily: 'Inter, sans-serif', toolbar: { show: false } };
  kpi5Labels:  string[]     = [];
  kpi5Colors:  string[]     = ['#1d4ed8','#2563eb','#60a5fa','#22c55e','#f59e0b','#f87171','#a78bfa'];
  kpi5PlotOpt: ApexPlotOptions = { pie: { donut: { size: '68%', labels: { show: true, total: { show: true, label: 'Incidencias', fontSize: '12px', fontWeight: 700, color: '#475569', formatter: () => '100%' } } } } };
  kpi5DataL:   ApexDataLabels = { enabled: false };
  kpi5Legend:  ApexLegend   = { position: 'bottom', fontSize: '12px', fontWeight: 600, markers: { size: 8 } };

  // KPI13 — Bar chart (Ingresos por comisiones)
  kpi13Series: ApexAxisChartSeries = [{ name: 'Ingresos (Bs)', data: [] }];
  kpi13Chart:  ApexChart    = { type: 'bar', height: 280, toolbar: { show: false }, fontFamily: 'Inter, sans-serif' };
  kpi13Xaxis:  ApexXAxis    = { categories: [], labels: { style: { colors: '#475569', fontSize: '11px', fontWeight: 600 } } };
  kpi13Colors: string[]     = ['#22c55e'];
  kpi13DataL:  ApexDataLabels = { enabled: true, formatter: (v: number) => `Bs${v}`, style: { fontSize: '10px' } };
  kpi13PlotOpt: ApexPlotOptions = { bar: { borderRadius: 4, dataLabels: { position: 'top' } } };

  // KPI14 — Heatmap (Horas Pico)
  kpi14Series: ApexAxisChartSeries = [];
  kpi14Chart:  ApexChart    = { type: 'heatmap', height: 350, toolbar: { show: false }, fontFamily: 'Inter, sans-serif' };
  kpi14PlotOpt: ApexPlotOptions = { heatmap: { shadeIntensity: 0.5, radius: 4, useFillColorAsStroke: false, colorScale: { ranges: [{ from: 0, to: 0, color: '#f8fafc', name: 'Nulo' }, { from: 1, to: 5, color: '#dbeafe', name: 'Bajo' }, { from: 6, to: 15, color: '#60a5fa', name: 'Medio' }, { from: 16, to: 1000, color: '#1d4ed8', name: 'Alto' }] } } };
  kpi14DataL:  ApexDataLabels = { enabled: false };

  // KPI15 — Donut (Retención)
  kpi15Series: ApexNonAxisChartSeries = [];
  kpi15Labels: string[] = [];
  kpi15Chart:  ApexChart = { type: 'pie', height: 280, fontFamily: 'Inter, sans-serif', toolbar: { show: false } };
  kpi15Colors: string[] = ['#1d4ed8', '#94a3b8'];
  kpi15Legend: ApexLegend = { position: 'bottom', fontSize: '12px', fontWeight: 600 };

  // KPI16 — Funnel (Horizontal Bar)
  kpi16Series: ApexAxisChartSeries = [{ name: 'Solicitudes', data: [] }];
  kpi16Chart:  ApexChart = { type: 'bar', height: 250, toolbar: { show: false }, fontFamily: 'Inter, sans-serif' };
  kpi16PlotOpt: ApexPlotOptions = { bar: { borderRadius: 4, horizontal: true, barHeight: '80%', isFunnel: true } };
  kpi16Colors: string[] = ['#3b82f6'];
  kpi16DataL:  ApexDataLabels = { enabled: true, formatter: (v: number) => v.toString(), style: { fontSize: '12px' } };
  kpi16Xaxis:  ApexXAxis = { categories: [] };


  constructor(@Inject(PLATFORM_ID) platformId: object) {
    this.isBrowser = isPlatformBrowser(platformId);
  }

  ngOnInit(): void {
    this.cargarDatos();
  }

  ngAfterViewInit(): void {
    if (this.isBrowser) {
      setTimeout(() => this.initHeatmap(), 200);
    }
  }

  aplicarFiltros(): void {
    this.cargarDatos();
  }

  private cargarDatos(): void {
    this.isLoading.set(true);
    const fi = this.fechaInicio() || undefined;
    const ff = this.fechaFin()    || undefined;

    forkJoin({
      kpi1: this.svc.getKpi1(fi, ff),
      kpi5: this.svc.getKpi5(fi, ff),
      kpi6: this.svc.getKpi6(fi, ff),
      kpi7: this.svc.getKpi7(fi, ff),
      kpi8: this.svc.getKpi8(fi, ff),
      kpi12: this.svc.getKpi12(fi, ff),
      kpi13: this.svc.getKpi13(fi, ff),
      kpi14: this.svc.getKpi14(fi, ff),
      kpi15: this.svc.getKpi15(fi, ff),
      kpi16: this.svc.getKpi16(fi, ff),
    }).subscribe({
      next: ({ kpi1, kpi5, kpi6, kpi7, kpi8, kpi12, kpi13, kpi14, kpi15, kpi16 }) => {
        this.kpi1.set(kpi1);
        this.kpi5.set(kpi5);
        this.kpi6.set(kpi6);
        this.kpi7.set(kpi7);
        this.kpi8.set([...kpi8].reverse()); // cronológico asc
        this.kpi12.set(kpi12);
        this.kpi13.set([...kpi13].reverse());
        this.kpi14.set(kpi14);
        this.kpi15.set(kpi15);
        this.kpi16.set(kpi16);

        this.buildKpi8Chart(this.kpi8());
        this.buildKpi5Chart(kpi5);
        this.buildKpi13Chart(this.kpi13());
        this.buildKpi14Chart(kpi14);
        this.buildKpi15Chart(kpi15);
        this.buildKpi16Chart(kpi16);
        this.updateHeatmap(kpi7);
        this.isLoading.set(false);
      },
      error: () => this.isLoading.set(false),
    });
  }

  private buildKpi8Chart(data: Kpi8CanceladosMes[]): void {
    this.kpi8Xaxis  = { ...this.kpi8Xaxis, categories: data.map(d => d.mes) };
    this.kpi8Series = [{ name: 'Tasa cancelación %', data: data.map(d => d.tasa_cancelacion_pct) }];
  }

  private buildKpi5Chart(data: Kpi5IncidenciaItem[]): void {
    this.kpi5Labels  = data.map(d => d.categoria_incidencia ?? 'Sin categoría');
    this.kpi5Series  = data.map(d => d.porcentaje);
  }

  private buildKpi13Chart(data: Kpi13IngresosComisiones[]): void {
    this.kpi13Xaxis = { ...this.kpi13Xaxis, categories: data.map(d => d.mes) };
    this.kpi13Series = [{ name: 'Comisiones (Bs)', data: data.map(d => d.total_comision) }];
  }

  private buildKpi14Chart(data: Kpi14HorasPico[]): void {
    const days = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    const series: ApexAxisChartSeries = [];
    
    // Create an empty matrix 7 days x 24 hours
    for (let d = 0; d < 7; d++) {
      const dataPoints = [];
      for (let h = 0; h < 24; h++) {
        // Find existing data
        const point = data.find(item => item.dia_semana === d && item.hora === h);
        dataPoints.push({
          x: `${h.toString().padStart(2, '0')}:00`,
          y: point ? point.cantidad : 0
        });
      }
      series.push({
        name: days[d],
        data: dataPoints
      });
    }
    // Reverse series so Sunday is at bottom
    this.kpi14Series = series.reverse();
  }

  private buildKpi15Chart(data: Kpi15RetencionClientes[]): void {
    this.kpi15Labels = data.map(d => d.tipo);
    this.kpi15Series = data.map(d => d.cantidad);
  }

  private buildKpi16Chart(data: Kpi16EmbudoAbandono[]): void {
    this.kpi16Xaxis = { ...this.kpi16Xaxis, categories: data.map(d => d.etapa) };
    this.kpi16Series = [{ name: 'Solicitudes', data: data.map(d => d.cantidad) }];
  }

  // ── Heatmap Leaflet ───────────────────────────────────────────────────────

  private initHeatmap(): void {
    if (!this.isBrowser || !this.heatmapEl?.nativeElement) return;
    if (this.heatmap) return;

    this.heatmap = L.map(this.heatmapEl.nativeElement, {
      center: [-17.7833, -63.1821],
      zoom: 13,
      zoomControl: true,
      scrollWheelZoom: false,
    });

    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
      maxZoom: 19,
      attribution: '&copy; Carto',
    }).addTo(this.heatmap);

    if (this.kpi7().length) this.updateHeatmap(this.kpi7());
  }

  private updateHeatmap(data: Kpi7MapaCalorItem[]): void {
    if (!this.heatmap) return;
    this.heatCircles.forEach(c => this.heatmap.removeLayer(c));
    this.heatCircles = [];

    const maxDensidad = Math.max(...data.map(d => d.densidad), 1);

    data.forEach(pt => {
      const opacity = 0.30 + (pt.densidad / maxDensidad) * 0.55;
      const circle = L.circleMarker([pt.latitud, pt.longitud], {
        radius: 20, // px fijos — estético a cualquier nivel de zoom
        fillColor: '#1d4ed8',
        fillOpacity: opacity,
        color: '#1d4ed8',
        weight: 1.5,
        opacity: 0.5,
      }).bindPopup(`<b>${pt.densidad} emergencia${pt.densidad > 1 ? 's' : ''}</b><br>${pt.latitud.toFixed(4)}, ${pt.longitud.toFixed(4)}`);
      circle.addTo(this.heatmap);
      this.heatCircles.push(circle);
    });

    if (data.length > 0) {
      const bounds = L.latLngBounds(data.map(d => [d.latitud, d.longitud] as [number, number]));
      this.heatmap.fitBounds(bounds, { padding: [40, 40] });
    }
  }

  ngOnDestroy(): void {
    if (this.heatmap) this.heatmap.remove();
  }

  // ── Helpers de template ───────────────────────────────────────────────────
  fmt(v: number | null | undefined, dec = 1): string {
    return v != null ? v.toFixed(dec) : '—';
  }

  deltaBadge(v: number | null | undefined): string {
    if (v == null) return 'text-gray-400 bg-gray-50';
    return v > 0 ? 'text-amber-700 bg-amber-50' : 'text-green-700 bg-green-50';
  }
}
