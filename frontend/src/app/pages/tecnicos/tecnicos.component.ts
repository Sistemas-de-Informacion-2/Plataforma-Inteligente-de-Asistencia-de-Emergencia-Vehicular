import { Component, OnInit, signal, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { EmpleadosService, Empleado } from '../../shared/api/empleados.service';
import { SucursalesService, Sucursal } from '../../shared/api/sucursales.service';

@Component({
  selector: 'app-tecnicos',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './tecnicos.component.html'
})
export class TecnicosComponent implements OnInit {
  private empleadosService = inject(EmpleadosService);
  private sucursalesService = inject(SucursalesService);
  private fb = inject(FormBuilder);

  // Estado vía Signals
  empleados = signal<Empleado[]>([]);
  sucursales = signal<Sucursal[]>([]);
  isLoading = signal(true);
  
  isModalOpen = signal(false);
  modalMode = signal<'create' | 'edit' | 'view'>('create');
  selectedEmpleadoId = signal<number | null>(null);

  isSubmitting = signal(false);
  
  // Toast notifications
  showToast = signal(false);
  
  // Error del backend
  errorMessage = signal<string | null>(null);

  empleadoForm!: FormGroup;

  ngOnInit(): void {
    this.initForm();
    this.loadData();
  }

  private initForm(): void {
    this.empleadoForm = this.fb.group({
      nombre: ['', [Validators.required, Validators.maxLength(100)]],
      ci: ['', [Validators.required, Validators.maxLength(20)]],
      telefono: ['', [Validators.required, Validators.maxLength(20)]],
      email: ['', [Validators.required, Validators.email, Validators.maxLength(150)]],
      password: ['', [Validators.required, Validators.minLength(6)]],
      especialidad: ['', [Validators.required, Validators.maxLength(150)]],
      sucursal_id: [null, Validators.required],
      disponible: [true] // Agregado para posible edicion
    });
  }

  private loadData(): void {
    this.isLoading.set(true);

    this.empleadosService.listarEmpleados().subscribe({
      next: (data) => {
        this.empleados.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error listando empleados', err);
        this.isLoading.set(false);
      }
    });

    this.sucursalesService.getMisTalleres().subscribe({
      next: (talleres) => {
        if (talleres && talleres.length > 0) {
          const tId = talleres[0].id;
          this.sucursalesService.listarSucursales(tId).subscribe({
            next: (sucs) => this.sucursales.set(sucs),
            error: (err) => console.error('Error listando sucursales', err)
          });
        }
      },
      error: (err) => console.error('Error obteniendo mis talleres', err)
    });
  }

  openModal(mode: 'create' | 'edit' | 'view', emp: Empleado | null = null): void {
    this.modalMode.set(mode);
    this.errorMessage.set(null);
    this.empleadoForm.reset({ disponible: true });
    
    if (mode === 'create') {
      this.empleadoForm.enable();
      // Asegurar que la password vuelve a ser obligatoria
      this.empleadoForm.get('password')?.setValidators([Validators.required, Validators.minLength(6)]);
      this.selectedEmpleadoId.set(null);
    } else if (emp) {
      this.selectedEmpleadoId.set(emp.id);
      
      // La password no es necesaria para edit/view del empleado
      this.empleadoForm.get('password')?.clearValidators();
      this.empleadoForm.get('password')?.updateValueAndValidity();

      this.empleadoForm.patchValue({
        nombre: emp.usuario?.nombre || '',
        ci: emp.usuario?.ci || '',
        telefono: emp.usuario?.telefono || '',
        email: emp.usuario?.email || '',
        especialidad: emp.especialidad || '',
        sucursal_id: emp.sucursal_id || null,
        disponible: emp.disponible
      });

      if (mode === 'view') {
        this.empleadoForm.disable();
      } else if (mode === 'edit') {
        this.empleadoForm.enable();
        // Los datos base del usuario no se editan en este endpoint
        this.empleadoForm.get('nombre')?.disable();
        this.empleadoForm.get('ci')?.disable();
        this.empleadoForm.get('email')?.disable();
        // Especialidad, Sucursal, Telefono(si backend soportara, pero no lo soporta en este endpoint) 
        // Asi que telefono tambien bloqueado
        this.empleadoForm.get('telefono')?.disable();
      }
    }
    
    this.isModalOpen.set(true);
  }

  closeModal(): void {
    this.isModalOpen.set(false);
    this.errorMessage.set(null);
  }

  onSubmit(): void {
    if (this.empleadoForm.invalid) {
      this.empleadoForm.markAllAsTouched();
      return;
    }

    this.errorMessage.set(null);
    this.isSubmitting.set(true);
    
    const rawValue = this.empleadoForm.getRawValue();
    const mode = this.modalMode();

    if (mode === 'create') {
      this.empleadosService.crearEmpleado(rawValue).subscribe({
        next: () => this.handleSuccess(),
        error: (err) => this.handleError(err)
      });
    } else if (mode === 'edit' && this.selectedEmpleadoId()) {
      // Para editar, backend EmpleadoUpdate solo recibe: 
      // especialidad, sucursal_id, disponible, latitud, longitud
      const updatePayload = {
        especialidad: rawValue.especialidad,
        sucursal_id: rawValue.sucursal_id,
        disponible: rawValue.disponible
      };

      this.empleadosService.actualizarEmpleado(this.selectedEmpleadoId()!, updatePayload).subscribe({
        next: () => this.handleSuccess(),
        error: (err) => this.handleError(err)
      });
    }
  }

  eliminarEmpleado(emp: Empleado): void {
    if (!confirm(`¿Estás seguro de que deseas eliminar al técnico ${emp.usuario?.nombre}? Esta acción restringirá su acceso.`)) {
      return;
    }

    this.empleadosService.eliminarEmpleado(emp.id).subscribe({
      next: () => {
        this.empleadosService.listarEmpleados().subscribe(data => this.empleados.set(data));
        this.triggerToast();
      },
      error: (err) => {
        console.error('Error eliminando empleado:', err);
        alert('Ocurrió un error al intentar eliminar el empleado.');
      }
    });
  }

  private handleSuccess(): void {
    this.empleadosService.listarEmpleados().subscribe(data => this.empleados.set(data));
    this.isSubmitting.set(false);
    this.closeModal();
    this.triggerToast();
  }

  private handleError(err: any): void {
    console.error('Error de operación:', err);
    if (err.error && err.error.detail) {
      this.errorMessage.set(err.error.detail);
    } else {
      this.errorMessage.set('Ocurrió un error inesperado al procesar la solicitud.');
    }
    this.isSubmitting.set(false);
  }

  private triggerToast(): void {
    this.showToast.set(true);
    setTimeout(() => {
      this.showToast.set(false);
    }, 3000);
  }
}
