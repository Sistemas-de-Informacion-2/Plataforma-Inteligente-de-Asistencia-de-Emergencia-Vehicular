import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { UsuarioService, UsuarioData } from '../../shared/api/usuario.service';

@Component({
  selector: 'app-perfil',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './perfil.component.html'
})
export class PerfilComponent implements OnInit {
  private fb = inject(FormBuilder);
  private usuarioService = inject(UsuarioService);

  perfilForm!: FormGroup;
  isLoading = true;
  isSaving = false;
  toastMessage: { type: 'success' | 'error', text: string } | null = null;

  ngOnInit(): void {
    this.initForm();
    this.loadProfile();
  }

  private initForm(): void {
    this.perfilForm = this.fb.group({
      // Datos de solo lectura
      email: [{ value: '', disabled: true }],
      ci: [{ value: '', disabled: true }],
      fecha_creacion: [{ value: '', disabled: true }],

      // Datos base editables
      nombre: ['', Validators.required],
      telefono: [''],

      // Datos de Perfil (UsuarioPerfil)
      segundo_nombre: [''],
      apellido_paterno: ['', Validators.required],
      apellido_materno: [''],
      foto_perfil: [''],
      fecha_nacimiento: ['']
    });
  }

  private loadProfile(): void {
    this.isLoading = true;
    this.usuarioService.getMe().subscribe({
      next: (user: UsuarioData) => {
        const perfil = user.perfil;
        
        // Formatear la fecha para input type="date" si existe
        let fechaFormatted = '';
        if (perfil?.fecha_nacimiento) {
          fechaFormatted = new Date(perfil.fecha_nacimiento).toISOString().split('T')[0];
        }

        let fechaCreacionFormatted = new Date(user.fecha_creacion).toLocaleDateString();

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
        
        this.isLoading = false;
      },
      error: (err) => {
        this.isLoading = false;
        this.showToast('error', 'No se pudo cargar el perfil. Intenta de nuevo.');
        console.error(err);
      }
    });
  }

  onSubmit(): void {
    if (this.perfilForm.invalid) {
      this.perfilForm.markAllAsTouched();
      return;
    }

    this.isSaving = true;
    
    // Obtenemos solo los campos pertinentes, los disabled se deben pedir explicitamente con getRawValue() o excluyendolos.
    // Usamos value porque los disabled no se mandarán y es exactamente lo que queremos.
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
      next: () => {
        this.isSaving = false;
        this.showToast('success', 'Perfil actualizado con éxito');
      },
      error: (err) => {
        this.isSaving = false;
        this.showToast('error', 'Ocurrió un error al actualizar el perfil');
        console.error(err);
      }
    });
  }

  private showToast(type: 'success' | 'error', text: string): void {
    this.toastMessage = { type, text };
    setTimeout(() => {
      this.toastMessage = null;
    }, 4000);
  }
}
