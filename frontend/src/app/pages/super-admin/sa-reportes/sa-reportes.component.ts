// src/app/pages/super-admin/sa-reportes/sa-reportes.component.ts
import { Component, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';

import {
  ReportesService,
  KPI_CARDS,
  ENTIDADES_META,
  type KpiCard,
  type ReporteManualRequest,
} from '../../../shared/api/reportes.service';

type Formato = 'xlsx' | 'csv' | 'pdf';

@Component({
  selector: 'app-sa-reportes',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './sa-reportes.component.html',
  styles: [`
    .shimmer {
      background: #f6f7f8;
      background-image: linear-gradient(to right, #f6f7f8 0%, #edeef1 20%, #f6f7f8 40%, #f6f7f8 100%);
      background-repeat: no-repeat;
      background-size: 800px 100%;
      animation: shimmer-ani 1.5s infinite linear;
    }
    @keyframes shimmer-ani {
      0% { background-position: -468px 0; }
      100% { background-position: 468px 0; }
    }
    .card-border-glow:hover { border-color: #60a5fa; }
    .animate-fade-in {
      animation: fadeInUp 0.45s ease forwards;
    }
    @keyframes fadeInUp {
      from { opacity: 0; transform: translateY(14px); }
      to   { opacity: 1; transform: translateY(0); }
    }
  `],
})
export class SaReportesComponent {
  private svc = inject(ReportesService);

  // ── KPIs disponibles para SA (sin KPI 11 que es exclusivo ADMIN_TALLER) ───
  readonly kpiCards: KpiCard[] = KPI_CARDS.filter(k => !k.soloTA);
  readonly entidades = Object.entries(ENTIDADES_META).map(([key, v]) => ({ key, label: v.label }));
  readonly formatos: Formato[] = ['xlsx', 'csv', 'pdf'];

  // ── Sección 1: Asistente IA ───────────────────────────────────────────────
  iaPrompt    = signal('');
  iaFormato   = signal<Formato>('xlsx');
  isIaLoading = signal(false);
  isRecording = signal(false);

  // ── Sección 2: KPIs Predefinidos ──────────────────────────────────────────
  predFechaInicio = signal('');
  predFechaFin    = signal('');
  isKpiLoading    = signal<string | null>(null);

  // ── Sección 3: Constructor Manual Relacional ──────────────────────────────
  manualTablaBase          = signal('SOLICITUDES');
  manualTablasRelacionadas = signal<string[]>([]);
  manualColumnas           = signal<string[]>([]);
  manualFechaInicio        = signal('');
  manualFechaFin           = signal('');
  manualFormato            = signal<Formato>('xlsx');
  isManualLoading          = signal(false);

  availableRelaciones = computed(
    () => ENTIDADES_META[this.manualTablaBase()]?.relaciones ?? []
  );

  availableColumnasPorEntidad = computed(() => {
    const entities = [this.manualTablaBase(), ...this.manualTablasRelacionadas()];
    return entities.map(entity => ({
      entity,
      label:   ENTIDADES_META[entity]?.label   ?? entity,
      columnas: ENTIDADES_META[entity]?.columnas ?? [],
    }));
  });

  availableColumnas = computed(() => {
    const all: string[] = [];
    for (const g of this.availableColumnasPorEntidad()) {
      for (const col of g.columnas) all.push(`${g.entity}.${col}`);
    }
    return all;
  });

  todasSeleccionadas = computed(() => {
    const av = this.availableColumnas();
    return av.length > 0 && this.manualColumnas().length === av.length;
  });

  entidadLabel(entity: string): string {
    return ENTIDADES_META[entity]?.label ?? entity;
  }

  // ── Sección 1 — IA ───────────────────────────────────────────────────────

  iniciarVoz(): void {
    const SR = (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition;
    if (!SR) {
      Swal.fire({ icon: 'warning', title: 'No soportado', text: 'Tu navegador no admite reconocimiento de voz. Usa Chrome o Edge.', timer: 3000, showConfirmButton: false });
      return;
    }
    if (this.isRecording()) return;

    const rec = new SR();
    rec.lang = 'es-ES';
    rec.continuous = false;
    rec.interimResults = false;

    rec.onstart  = () => this.isRecording.set(true);
    rec.onerror  = () => this.isRecording.set(false);
    rec.onend    = () => this.isRecording.set(false);
    rec.onresult = (event: any) => {
      const texto = event.results[0][0].transcript.trim();
      this.iaPrompt.set(texto);
      this.isRecording.set(false);
      this.generarConIA();
    };

    rec.start();
  }

  generarConIA(): void {
    const prompt = this.iaPrompt().trim();
    if (!prompt) {
      Swal.fire({ icon: 'warning', title: 'Prompt vacío', text: 'Describe el reporte que necesitas antes de continuar.', timer: 2500, showConfirmButton: false });
      return;
    }
    this.isIaLoading.set(true);
    this.svc.getIa({ prompt, formato: this.iaFormato() }).subscribe({
      next: (blob) => {
        this.isIaLoading.set(false);
        this.descargarBlob(blob, `reporte-ia.${this.iaFormato()}`);
      },
      error: () => {
        this.isIaLoading.set(false);
        Swal.fire({ icon: 'error', title: 'Error al interpretar', text: 'Gemini no pudo procesar el prompt. Revisa la configuración de GEMINI_API_KEY en el servidor.', confirmButtonColor: '#1d4ed8' });
      },
    });
  }

  // ── Sección 2 — KPIs Predefinidos ────────────────────────────────────────

  descargarKpi(kpiId: number, formato: Formato): void {
    const key = `${kpiId}-${formato}`;
    if (this.isKpiLoading() === key) return;

    this.isKpiLoading.set(key);
    const fi = this.predFechaInicio() || undefined;
    const ff = this.predFechaFin()    || undefined;

    this.svc.getPredefinido(kpiId, formato, fi, ff).subscribe({
      next: (blob) => {
        this.isKpiLoading.set(null);
        this.descargarBlob(blob, `kpi${kpiId}.${formato}`);
      },
      error: () => {
        this.isKpiLoading.set(null);
        Swal.fire({ icon: 'error', title: 'Error al descargar', text: `No se pudo obtener el KPI ${kpiId} en formato ${formato.toUpperCase()}.`, confirmButtonColor: '#1d4ed8' });
      },
    });
  }

  isKpiLoadingKey(kpiId: number, formato: Formato): boolean {
    return this.isKpiLoading() === `${kpiId}-${formato}`;
  }

  // ── Sección 3 — Constructor Manual ───────────────────────────────────────

  onTablaBaseChange(v: string): void {
    this.manualTablaBase.set(v);
    this.manualTablasRelacionadas.set([]);
    this.manualColumnas.set([]);
  }

  toggleRelacionada(entity: string): void {
    const current = this.manualTablasRelacionadas();
    this.manualTablasRelacionadas.set(
      current.includes(entity) ? current.filter(e => e !== entity) : [...current, entity]
    );
    this.manualColumnas.set([]);
  }

  toggleColumna(col: string): void {
    const current = this.manualColumnas();
    this.manualColumnas.set(
      current.includes(col) ? current.filter(c => c !== col) : [...current, col]
    );
  }

  toggleTodasColumnas(): void {
    this.manualColumnas.set(
      this.todasSeleccionadas() ? [] : [...this.availableColumnas()]
    );
  }

  exportarManual(): void {
    this.isManualLoading.set(true);
    const req: ReporteManualRequest = {
      tabla_base:          this.manualTablaBase(),
      tablas_relacionadas: this.manualTablasRelacionadas(),
      columnas:            this.manualColumnas(),
      filtros:             {},
      formato:             this.manualFormato(),
      fecha_inicio:        this.manualFechaInicio() || undefined,
      fecha_fin:           this.manualFechaFin()    || undefined,
    };

    this.svc.getDinamico(req).subscribe({
      next: (blob) => {
        this.isManualLoading.set(false);
        const nombre = `reporte-${this.manualTablaBase().toLowerCase()}.${this.manualFormato()}`;
        this.descargarBlob(blob, nombre);
      },
      error: () => {
        this.isManualLoading.set(false);
        Swal.fire({ icon: 'error', title: 'Error al exportar', text: 'El servidor no pudo generar el reporte. Revisa los parámetros e intenta de nuevo.', confirmButtonColor: '#1d4ed8' });
      },
    });
  }

  // ── Utilidad de descarga via elemento <a> invisible ──────────────────────

  private descargarBlob(blob: Blob, filename: string): void {
    const url = URL.createObjectURL(blob);
    const a   = document.createElement('a');
    a.href     = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}
