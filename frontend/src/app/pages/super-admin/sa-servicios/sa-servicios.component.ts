// src/app/pages/super-admin/sa-servicios/sa-servicios.component.ts
import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { SuperAdminService, Servicio } from '../../../shared/api/super-admin.service';

@Component({
  selector: 'app-sa-servicios',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './sa-servicios.component.html'
})
export class SaServiciosComponent implements OnInit {
  private api = inject(SuperAdminService);
  private fb = inject(FormBuilder);

  // Estado vía Signals
  servicios = signal<Servicio[]>([]);
  isLoading = signal(true);

  isModalOpen = signal(false);
  modalMode = signal<'create' | 'edit'>('create');
  selectedId = signal<number | null>(null);

  isSubmitting = signal(false);
  showToast = signal(false);
  toastMessage = signal('');
  errorMessage = signal<string | null>(null);

  servicioForm!: FormGroup;

  ngOnInit(): void {
    this.initForm();
    this.loadServicios();
  }

  private initForm(): void {
    this.servicioForm = this.fb.group({
      nombre: ['', [Validators.required, Validators.maxLength(150)]],
      descripcion: ['']
    });
  }

  private loadServicios(): void {
    this.isLoading.set(true);
    this.api.getServicios().subscribe({
      next: (data) => {
        this.servicios.set(data);
        this.isLoading.set(false);
      },
      error: (err: any) => {
        console.error('Error cargando servicios:', err);
        this.isLoading.set(false);
      }
    });
  }

  openModal(mode: 'create' | 'edit', servicio: Servicio | null = null): void {
    this.modalMode.set(mode);
    this.errorMessage.set(null);
    this.servicioForm.reset();

    if (mode === 'edit' && servicio) {
      this.selectedId.set(servicio.id);
      this.servicioForm.patchValue({
        nombre: servicio.nombre,
        descripcion: servicio.descripcion || ''
      });
    } else {
      this.selectedId.set(null);
    }

    this.isModalOpen.set(true);
  }

  closeModal(): void {
    this.isModalOpen.set(false);
    this.errorMessage.set(null);
  }

  onSubmit(): void {
    if (this.servicioForm.invalid) {
      this.servicioForm.markAllAsTouched();
      return;
    }

    this.errorMessage.set(null);
    this.isSubmitting.set(true);

    const payload = this.servicioForm.getRawValue();
    const mode = this.modalMode();

    if (mode === 'create') {
      this.api.crearServicio(payload).subscribe({
        next: () => this.handleSuccess('Servicio creado exitosamente'),
        error: (err: any) => this.handleError(err)
      });
    } else if (mode === 'edit' && this.selectedId()) {
      this.api.actualizarServicio(this.selectedId()!, payload).subscribe({
        next: () => this.handleSuccess('Servicio actualizado exitosamente'),
        error: (err: any) => this.handleError(err)
      });
    }
  }

  eliminarServicio(servicio: Servicio): void {
    if (!confirm(`¿Eliminar el servicio "${servicio.nombre}" del catálogo? Esta acción es permanente.`)) {
      return;
    }

    this.api.eliminarServicio(servicio.id).subscribe({
      next: () => {
        this.loadServicios();
        this.triggerToast('Servicio eliminado del catálogo');
      },
      error: (err: any) => {
        console.error('Error eliminando servicio:', err);
        alert('Ocurrió un error al eliminar el servicio.');
      }
    });
  }

  private handleSuccess(message: string): void {
    this.loadServicios();
    this.isSubmitting.set(false);
    this.closeModal();
    this.triggerToast(message);
  }

  private handleError(err: any): void {
    console.error('Error de operación:', err);
    if (err.error?.detail) {
      this.errorMessage.set(err.error.detail);
    } else {
      this.errorMessage.set('Ocurrió un error inesperado.');
    }
    this.isSubmitting.set(false);
  }

  private triggerToast(message: string): void {
    this.toastMessage.set(message);
    this.showToast.set(true);
    setTimeout(() => this.showToast.set(false), 3000);
  }
}
