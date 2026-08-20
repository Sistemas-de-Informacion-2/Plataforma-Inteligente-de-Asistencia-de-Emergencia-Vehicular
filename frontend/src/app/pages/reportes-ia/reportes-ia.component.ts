// frontend/src/app/pages/reportes-ia/reportes-ia.component.ts
import { Component, OnInit, inject, OnDestroy, ViewChild, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-reportes-ia',
  standalone: true,
  imports: [CommonModule],
  template: `
    <!-- 
      Usamos absolute inset-0 z-50 para cubrir todo el contenedor <main relative> de Angular,
      ignorando su padding interno y el max-w-7xl, llenando exactamente el 100% de la pantalla útil
      sin causar scrollbars dobles ni parpadeos. 
    -->
    <div class="absolute inset-0 z-[50] flex flex-col bg-[#0f1117] text-slate-200 overflow-hidden">
      
      <!-- Indicador de Carga Inicial -->
      <div *ngIf="loading && !rawEmbedUrl" class="flex flex-col items-center justify-center flex-1">
        <div class="animate-spin rounded-full h-10 w-10 border-t-2 border-b-2 border-indigo-500 mb-4"></div>
        <p class="text-indigo-400 font-medium text-sm">Cargando Centro de Reportes e Inteligencia Artificial...</p>
      </div>

      <!-- Pantalla de Error -->
      <div *ngIf="error && !rawEmbedUrl" class="flex flex-col items-center justify-center flex-1 p-8 text-center">
        <div class="bg-red-900/20 border border-red-500/30 text-red-400 p-6 rounded-xl max-w-lg mx-auto">
          <svg class="w-12 h-12 mx-auto mb-4 text-red-500/80" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <h3 class="text-lg font-bold mb-2">Error de Conexión</h3>
          <p class="text-sm mb-4">{{ error }}</p>
          <button (click)="loadToken()" class="bg-red-500/20 hover:bg-red-500/30 text-red-300 px-4 py-2 rounded-lg transition-colors text-sm font-medium">
            Reintentar
          </button>
        </div>
      </div>

      <!-- Iframe Fluido a Pantalla Completa REACTIVADO con URL de prueba -->
      <iframe 
        #reportIframe
        [style.display]="rawEmbedUrl ? 'block' : 'none'"
        class="w-full h-full border-none bg-[#0f1117]"
        title="ReportIQ Studio"
        sandbox="allow-scripts allow-same-origin allow-forms allow-popups"
        allowfullscreen>
      </iframe>
    </div>
  `
})
export class ReportesIaComponent implements OnInit, OnDestroy {
  private http = inject(HttpClient);

  @ViewChild('reportIframe') iframeRef?: ElementRef<HTMLIFrameElement>;

  loading = true;
  error: string | null = null;
  rawEmbedUrl: string | null = null;

  ngOnInit() {
    console.log('[ReportesIaComponent] ngOnInit called');
    this.loadToken();
    document.body.style.overflow = 'hidden';
  }

  ngOnDestroy() {
    console.log('[ReportesIaComponent] ngOnDestroy called');
    document.body.style.overflow = '';
  }

  loadToken() {
    console.log('[ReportesIaComponent] loadToken called');
    this.error = null;
    if (!this.rawEmbedUrl) {
      this.loading = true;
    }
    
    const url = `${environment.apiUrl}/reportes/token-reportiq`;

    this.http.get<{token_reportiq: string}>(url).subscribe({
      next: (res) => {
        console.log('[ReportesIaComponent] Token recibido:', res.token_reportiq);
        const embedUrl = `${environment.reportIqUrl}/embed?token=${encodeURIComponent(res.token_reportiq)}`;
        
        this.rawEmbedUrl = embedUrl;
        this.loading = false;

        // Asignar src al DOM nativo SOLO UNA VEZ.
        // Evita que el Change Detection de Angular toque iframe.src en cada ciclo.
        setTimeout(() => {
          if (this.iframeRef?.nativeElement) {
            console.log('[ReportesIaComponent] Asignando src al iframe nativo una sola vez:', embedUrl);
            this.iframeRef.nativeElement.src = embedUrl;
          }
        }, 0);
      },
      error: (err) => {
        console.error('Error fetching embed token:', err);
        this.error = err.error?.detail || 'No se pudo generar el token seguro para acceder a los reportes.';
        this.loading = false;
      }
    });
  }
}
