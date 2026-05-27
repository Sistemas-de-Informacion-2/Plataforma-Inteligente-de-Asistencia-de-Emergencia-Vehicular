import { Component, OnInit, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import Swal from 'sweetalert2';
import { RolesService, Rol, Permiso, RolCreate, RolUpdate } from '../../../shared/api/roles.service';

@Component({
  selector: 'app-sa-roles',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './sa-roles.component.html'
})
export class SaRolesComponent implements OnInit {
  private rolesService = inject(RolesService);

  roles = signal<Rol[]>([]);
  permisos = signal<Permiso[]>([]);
  
  // Estado del Modal
  isModalOpen = signal<boolean>(false);
  isEditing = signal<boolean>(false);
  
  // Formulario
  rolActual = signal<Partial<Rol>>({});
  permisosSeleccionados = signal<Set<number>>(new Set());

  ngOnInit() {
    this.cargarDatos();
  }

  cargarDatos() {
    this.rolesService.getRoles().subscribe({
      next: (data) => this.roles.set(data),
      error: (err) => console.error('Error cargando roles', err)
    });
    
    this.rolesService.getPermisos().subscribe({
      next: (data) => this.permisos.set(data),
      error: (err) => console.error('Error cargando permisos', err)
    });
  }

  abrirModalNuevo() {
    this.isEditing.set(false);
    this.rolActual.set({ nombre: '' });
    this.permisosSeleccionados.set(new Set());
    this.isModalOpen.set(true);
  }

  abrirModalEditar(rol: Rol) {
    this.isEditing.set(true);
    this.rolActual.set({ id: rol.id, nombre: rol.nombre });
    this.permisosSeleccionados.set(new Set(rol.permisos.map(p => p.id)));
    this.isModalOpen.set(true);
  }

  cerrarModal() {
    this.isModalOpen.set(false);
    this.rolActual.set({});
    this.permisosSeleccionados.set(new Set());
  }

  togglePermiso(permisoId: number) {
    const seleccionados = new Set(this.permisosSeleccionados());
    if (seleccionados.has(permisoId)) {
      seleccionados.delete(permisoId);
    } else {
      seleccionados.add(permisoId);
    }
    this.permisosSeleccionados.set(seleccionados);
  }

  guardarRol() {
    const rolData = this.rolActual();
    if (!rolData.nombre || rolData.nombre.trim() === '') {
      Swal.fire('Atención', 'El nombre del rol es obligatorio', 'warning');
      return;
    }

    const permisosIds = Array.from(this.permisosSeleccionados());

    if (this.isEditing() && rolData.id) {
      const updatePayload: RolUpdate = {
        nombre: rolData.nombre,
        permisos_ids: permisosIds
      };
      this.rolesService.updateRol(rolData.id, updatePayload).subscribe({
        next: () => {
          this.cargarDatos();
          this.cerrarModal();
        },
        error: (err) => {
          console.error('Error actualizando rol', err);
          Swal.fire('Error', 'Hubo un error al actualizar el rol', 'error');
        }
      });
    } else {
      const createPayload: RolCreate = {
        nombre: rolData.nombre,
        permisos_ids: permisosIds
      };
      this.rolesService.createRol(createPayload).subscribe({
        next: () => {
          this.cargarDatos();
          this.cerrarModal();
        },
        error: (err) => {
          console.error('Error creando rol', err);
          Swal.fire('Error', 'Hubo un error al crear el rol', 'error');
        }
      });
    }
  }

  eliminarRol(id: number) {
    Swal.fire({
      title: '¿Eliminar rol?',
      text: '¿Estás seguro de que deseas eliminar este rol?',
      icon: 'warning',
      showCancelButton: true,
      confirmButtonColor: '#d33',
      cancelButtonColor: '#3085d6',
      confirmButtonText: 'Sí, eliminar',
      cancelButtonText: 'Cancelar'
    }).then((result) => {
      if (result.isConfirmed) {
        this.rolesService.deleteRol(id).subscribe({
          next: () => {
            this.cargarDatos();
          },
          error: (err) => {
            console.error('Error eliminando rol', err);
            Swal.fire('Error', 'Hubo un error al eliminar el rol. Recuerda que los roles del sistema no pueden eliminarse.', 'error');
          }
        });
      }
    });
  }
}
