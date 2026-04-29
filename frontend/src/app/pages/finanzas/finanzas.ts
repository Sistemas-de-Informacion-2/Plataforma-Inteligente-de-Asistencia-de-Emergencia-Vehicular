import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { PagosService } from '../../shared/api/pagos.service';
import { UsuarioService } from '../../shared/api/usuario.service';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-finanzas',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './finanzas.html',
  styleUrl: './finanzas.css',
})
export class Finanzas implements OnInit {
  private pagosService = inject(PagosService);
  private usuarioService = inject(UsuarioService);

  deudaActual = signal<number>(0);
  limiteDeuda = signal<number>(150);
  puedeAceptar = signal<boolean>(true);
  
  qrUrl = signal<string | null>(null);
  isUploading = signal<boolean>(false);
  isLoading = signal<boolean>(true);
  toastMessage = signal<{ type: 'success' | 'error', text: string } | null>(null);

  ngOnInit() {
    this.cargarDatos();
  }

  cargarDatos() {
    this.isLoading.set(true);
    
    // Cargar deuda
    this.pagosService.consultarDeuda().subscribe({
      next: (res) => {
        this.deudaActual.set(res.deuda_actual);
        this.limiteDeuda.set(res.limite);
        this.puedeAceptar.set(res.puede_aceptar_solicitudes);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('[Finanzas] Error al cargar deuda:', err);
        this.isLoading.set(false);
        this.showToast('error', 'Error al cargar los datos de deuda.');
      }
    });

    // Cargar QR del admin autenticado
    this.usuarioService.getMiQr().subscribe({
        next: (res) => {
            if (res.qr_url) {
                if (res.qr_url.startsWith('/')) {
                    this.qrUrl.set(environment.backendUrl + res.qr_url);
                } else {
                    this.qrUrl.set(res.qr_url);
                }
            }
        },
        error: (err) => {
            console.error('[Finanzas] Error al cargar QR:', err);
        }
    });
  }

  onQrSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      this.isUploading.set(true);
      this.usuarioService.uploadQrAdmin(file).subscribe({
        next: (res) => {
          this.isUploading.set(false);
          const url = res.url.startsWith('/') ? environment.backendUrl + res.url : res.url;
          this.qrUrl.set(url);
          this.showToast('success', 'QR guardado exitosamente.');
        },
        error: (err) => {
          console.error('[Finanzas] Error al subir QR:', err);
          this.isUploading.set(false);
          this.showToast('error', 'Error al subir el QR.');
        }
      });
    }
  }

  private showToast(type: 'success' | 'error', text: string) {
    this.toastMessage.set({ type, text });
    setTimeout(() => this.toastMessage.set(null), 4000);
  }
}
