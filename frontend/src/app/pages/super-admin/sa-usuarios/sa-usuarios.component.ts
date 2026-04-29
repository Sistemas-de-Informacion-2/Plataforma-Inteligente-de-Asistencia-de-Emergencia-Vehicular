// src/app/pages/super-admin/sa-usuarios/sa-usuarios.component.ts
import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { SuperAdminService, UsuarioOut } from '../../../shared/api/super-admin.service';

@Component({
  selector: 'app-sa-usuarios',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './sa-usuarios.component.html'
})
export class SaUsuariosComponent implements OnInit {
  private api = inject(SuperAdminService);

  // Estado vía Signals
  usuarios = signal<UsuarioOut[]>([]);
  isLoading = signal(true);

  showToast = signal(false);
  toastMessage = signal('');

  ngOnInit(): void {
    this.loadUsuarios();
  }

  private loadUsuarios(): void {
    this.isLoading.set(true);
    this.api.getUsuarios().subscribe({
      next: (data) => {
        this.usuarios.set(data);
        this.isLoading.set(false);
      },
      error: (err: any) => {
        console.error('Error cargando usuarios:', err);
        this.isLoading.set(false);
      }
    });
  }

  banearUsuario(usuario: UsuarioOut): void {
    if (!confirm(`¿Banear al usuario "${usuario.nombre}" (${usuario.email})? No podrá volver a registrarse.`)) {
      return;
    }

    this.api.banearUsuario(usuario.id).subscribe({
      next: () => {
        this.loadUsuarios();
        this.triggerToast(`Usuario "${usuario.nombre}" baneado exitosamente`);
      },
      error: (err: any) => {
        console.error('Error baneando usuario:', err);
        if (err.error?.detail) {
          alert(err.error.detail);
        } else {
          alert('Ocurrió un error al banear al usuario.');
        }
      }
    });
  }

  private triggerToast(message: string): void {
    this.toastMessage.set(message);
    this.showToast.set(true);
    setTimeout(() => this.showToast.set(false), 3000);
  }
}
