import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormBuilder, FormGroup, ReactiveFormsModule, Validators } from '@angular/forms';
import { TecnicosService, Tecnico } from '../../shared/api/tecnicos.service';

@Component({
  selector: 'app-tecnicos',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './tecnicos.component.html'
})
export class TecnicosComponent implements OnInit {
  // Estado Reactivo Principal
  public tecnicos = signal<Tecnico[]>([]);
  public isLoading = signal<boolean>(true);

  // Estado del Modal
  public isModalOpen = signal<boolean>(false);
  public isEditing = signal<boolean>(false);
  public isSubmitting = signal<boolean>(false);
  public tecnicoIdSeleccionado: number | null = null;

  // Formulario Reactivo
  public form: FormGroup;

  public especialidades = [
    'Mecánica General',
    'Electricidad',
    'Llantas',
    'Grúa'
  ];

  constructor(
    private tecnicosService: TecnicosService,
    private fb: FormBuilder
  ) {
    this.form = this.fb.group({
      nombre: ['', [Validators.required, Validators.maxLength(150)]],
      telefono: ['', [Validators.required, Validators.maxLength(20)]],
      especialidad: ['', Validators.required],
      estado: ['DISPONIBLE', Validators.required]
    });
  }

  ngOnInit(): void {
    this.cargarTecnicos();
  }

  cargarTecnicos(): void {
    this.isLoading.set(true);
    this.tecnicosService.getTecnicos().subscribe({
      next: (data) => {
        this.tecnicos.set(data);
        this.isLoading.set(false);
      },
      error: (err) => {
        console.error('Error al cargar técnicos:', err);
        // Fallback Mock para demostración si no hay backend activo
        this.tecnicos.set([
          { id: 1, nombre: 'Carlos Mendoza', especialidad: 'Mecánica General', telefono: '+591 76543210', estado: 'DISPONIBLE' },
          { id: 2, nombre: 'Lucía Fernández', especialidad: 'Electricidad', telefono: '+591 71234567', estado: 'OCUPADO' },
          { id: 3, nombre: 'Mario Ugarte', especialidad: 'Grúa', telefono: '+591 78901234', estado: 'INACTIVO' }
        ]);
        this.isLoading.set(false);
      }
    });
  }

  abrirModalNuevo(): void {
    this.isEditing.set(false);
    this.tecnicoIdSeleccionado = null;
    this.form.reset({ estado: 'DISPONIBLE' });
    this.isModalOpen.set(true);
  }

  abrirModalEditar(tec: Tecnico): void {
    this.isEditing.set(true);
    this.tecnicoIdSeleccionado = tec.id;
    this.form.patchValue({
      nombre: tec.nombre,
      telefono: tec.telefono,
      especialidad: tec.especialidad,
      estado: tec.estado
    });
    this.isModalOpen.set(true);
  }

  cerrarModal(): void {
    this.isModalOpen.set(false);
    this.form.reset();
  }

  guardar(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    this.isSubmitting.set(true);
    const payload = this.form.value;

    if (this.isEditing() && this.tecnicoIdSeleccionado) {
      this.tecnicosService.actualizarTecnico(this.tecnicoIdSeleccionado, payload).subscribe({
        next: (tecActualizado) => {
          this.tecnicos.update(arr => arr.map(t => t.id === tecActualizado.id ? tecActualizado : t));
          this.finalizarGuardado();
        },
        error: (err) => {
          console.error(err);
          // Actualización optimista del signal en modo local-demo:
          const mockTec = { ...payload, id: this.tecnicoIdSeleccionado } as Tecnico;
          this.tecnicos.update(arr => arr.map(t => t.id === mockTec.id ? mockTec : t));
          this.finalizarGuardado();
        }
      });
    } else {
      this.tecnicosService.crearTecnico(payload).subscribe({
        next: (nuevoTec) => {
          this.tecnicos.update(arr => [...arr, nuevoTec]);
          this.finalizarGuardado();
        },
        error: (err) => {
          console.error(err);
          // Creación optimista del signal en modo local-demo:
          const mockTec = { ...payload, id: Math.floor(Math.random() * 1000) } as Tecnico;
          this.tecnicos.update(arr => [...arr, mockTec]);
          this.finalizarGuardado();
        }
      });
    }
  }

  private finalizarGuardado(): void {
    this.isSubmitting.set(false);
    this.cerrarModal();
  }

  eliminar(id: number): void {
    if(confirm('Aviso Crítico: ¿Estás seguro de eliminar los accesos de este técnico?')) {
      this.tecnicosService.eliminarTecnico(id).subscribe({
        next: () => {
          this.tecnicos.update(arr => arr.filter(t => t.id !== id));
        },
        error: (err) => {
          console.error(err);
          this.tecnicos.update(arr => arr.filter(t => t.id !== id));
        }
      });
    }
  }
}
