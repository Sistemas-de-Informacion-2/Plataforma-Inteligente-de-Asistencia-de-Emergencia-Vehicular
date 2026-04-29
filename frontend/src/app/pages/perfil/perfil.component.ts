import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { UsuarioService, UsuarioData } from '../../shared/api/usuario.service';
import { environment } from '../../../environments/environment';

@Component({
  selector: 'app-perfil',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './perfil.component.html',
  styleUrl: './perfil.component.css'
})
export class PerfilComponent implements OnInit {
  private fb = inject(FormBuilder);
  private usuarioService = inject(UsuarioService);

  perfilForm!: FormGroup;
  
  // Estados usando Signals (Angular Moderno)
  isLoading = signal(true);
  isSaving = signal(false);
  toastMessage = signal<{ type: 'success' | 'error', text: string } | null>(null);

  ngOnInit(): void {
    this.initForm();
    this.loadProfile();
  }

  private initForm(): void {
    this.perfilForm = this.fb.group({
      email: [{ value: '', disabled: true }],
      ci: [{ value: '', disabled: true }],
      fecha_creacion: [{ value: '', disabled: true }],
      nombre: ['', Validators.required],
      telefono: [''],
      segundo_nombre: [''],
      apellido_paterno: ['', Validators.required],
      apellido_materno: [''],
      foto_perfil: [''],
      fecha_nacimiento: ['']
    });
  }

  private loadProfile(): void {
    this.isLoading.set(true);
    this.usuarioService.getMe().subscribe({
      next: (user: UsuarioData) => {
        const perfil = user.perfil;
        const fechaFormatted = perfil?.fecha_nacimiento ? new Date(perfil.fecha_nacimiento).toISOString().split('T')[0] : '';
        const fechaCreacionFormatted = new Date(user.fecha_creacion).toLocaleDateString();

        this.perfilForm.patchValue({
          email: user.email,
          ci: user.ci,
          fecha_creacion: fechaCreacionFormatted,
          nombre: user.nombre,
          telefono: user.telefono || '',
          segundo_nombre: perfil?.segundo_nombre || '',
          apellido_paterno: perfil?.apellido_paterno || '',
          apellido_materno: perfil?.apellido_materno || '',
          foto_perfil: perfil?.foto_perfil || '',
          fecha_nacimiento: fechaFormatted
        });
        
        this.isLoading.set(false);
      },
      error: () => {
        this.isLoading.set(false);
        this.showToast('error', 'No se pudo cargar el perfil.');
      }
    });
  }

  // Estado adicional para la subida de la foto
  isUploadingPhoto = signal(false);

  // Helper para resolver la URL de la imagen en el template
  getAvatarUrl(): string | null {
    const url = this.perfilForm.get('foto_perfil')?.value;
    if (!url) return null;
    
    // Si la URL es relativa (nuestro servidor local), le añadimos el host
    if (url.startsWith('/uploads/')) {
      return `${environment.backendUrl}${url}`;
    }
    // Si ya es una URL completa (ej. AWS S3), la devolvemos tal cual
    return url;
  }

  onSubmit(): void {
    if (this.perfilForm.invalid) {
      this.perfilForm.markAllAsTouched();
      return;
    }

    this.isSaving.set(true);
    const formVals = this.perfilForm.value;
    
    const payload = {
      nombre: formVals.nombre,
      telefono: formVals.telefono,
      segundo_nombre: formVals.segundo_nombre || null,
      apellido_paterno: formVals.apellido_paterno,
      apellido_materno: formVals.apellido_materno || null,
      foto_perfil: formVals.foto_perfil || null,
      fecha_nacimiento: formVals.fecha_nacimiento || null,
    };

    this.usuarioService.updateMyProfile(payload).subscribe({
      next: (updatedUser: UsuarioData) => {
        this.isSaving.set(false);
        this.showToast('success', 'Perfil actualizado con éxito');
        
        // Sincronizamos el formulario con la respuesta real del servidor
        const perfil = updatedUser.perfil;
        const fechaFormatted = perfil?.fecha_nacimiento ? new Date(perfil.fecha_nacimiento).toISOString().split('T')[0] : '';
        
        this.perfilForm.patchValue({
          nombre: updatedUser.nombre,
          telefono: updatedUser.telefono,
          segundo_nombre: perfil?.segundo_nombre || '',
          apellido_paterno: perfil?.apellido_paterno || '',
          apellido_materno: perfil?.apellido_materno || '',
          foto_perfil: perfil?.foto_perfil || '',
          fecha_nacimiento: fechaFormatted
        });
      },
      error: () => {
        this.isSaving.set(false);
        this.showToast('error', 'Error al actualizar el perfil');
      }
    });
  }

  // Lógica de Foto de Perfil (Subida real tipo WhatsApp)
  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      // Validar tamaño (máx 2MB)
      if (file.size > 2 * 1024 * 1024) {
        this.showToast('error', 'La imagen es demasiado pesada (máx 2MB)');
        return;
      }

      this.isUploadingPhoto.set(true);
      
      this.usuarioService.uploadProfilePhoto(file).subscribe({
        next: (response) => {
          // El backend nos devuelve {"url": "/uploads/perfil_xxx.jpg"}
          this.perfilForm.patchValue({
            foto_perfil: response.url
          });
          this.isUploadingPhoto.set(false);
          this.showToast('success', 'Foto subida. ¡No olvides Guardar Cambios!');
        },
        error: () => {
          this.isUploadingPhoto.set(false);
          this.showToast('error', 'Error de conexión al subir la foto');
        }
      });
    }
  }

  private showToast(type: 'success' | 'error', text: string): void {
    this.toastMessage.set({ type, text });
    setTimeout(() => this.toastMessage.set(null), 4000);
  }
}
