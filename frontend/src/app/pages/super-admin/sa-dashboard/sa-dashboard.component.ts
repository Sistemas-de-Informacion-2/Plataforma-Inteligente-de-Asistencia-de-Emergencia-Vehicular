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
    }).subscribe({
      next: ({ kpi1, kpi5, kpi6, kpi7, kpi8 }) => {
        this.kpi1.set(kpi1);
        this.kpi5.set(kpi5);
        this.kpi6.set(kpi6);
        this.kpi7.set(kpi7);
        this.kpi8.set([...kpi8].reverse()); // cronológico asc

        this.buildKpi8Chart(this.kpi8());
        this.buildKpi5Chart(kpi5);
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
  fmt(v: number | null, dec = 1): string {
    return v != null ? v.toFixed(dec) : '—';
  }

  deltaBadge(v: number | null): string {
    if (v == null) return 'text-gray-400 bg-gray-50';
    return v > 0 ? 'text-amber-700 bg-amber-50' : 'text-green-700 bg-green-50';
  }
}
