import { Component, inject, signal, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, RouterOutlet } from '@angular/router';
import { AuthService } from '../../../shared/api/auth.service';
import { WebsocketService } from '../../../core/services/websocket.service';
import { PagosService } from '../../../shared/api/pagos.service';
import { NotificacionesService } from '../../../shared/api/notificaciones.service';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-admin-layout',
  standalone: true,
  imports: [CommonModule, RouterModule, RouterOutlet],
  templateUrl: './admin-layout.component.html',
  styleUrl: './admin-layout.component.css'
})
export class AdminLayoutComponent implements OnInit, OnDestroy {
  private authService = inject(AuthService);
  private wsService = inject(WebsocketService);
  public pagosService = inject(PagosService);
  public notificacionesService = inject(NotificacionesService);

  isSidebarOpen = window.innerWidth >= 768;
  isProfileMenuOpen = false;
  user = this.authService.currentUser;
  notificationCount = signal<number>(0);
  private wsSubscription?: Subscription;

  ngOnInit() {
    // Cargar deuda inicial
    this.pagosService.consultarDeuda().subscribe({
      next: (res) => {
        this.pagosService.deudaGlobal.set(res.deuda_actual);
        this.pagosService.limiteGlobal.set(res.limite);
      }
    });

    this.wsSubscription = this.wsService.getNotifications().subscribe(notif => {
      if (notif.type === 'NUEVA_SOLICITUD_EMERGENCIA') {
        this.notificationCount.update(c => c + 1);
      } else if (notif.type === 'DEUDA_ACTUALIZADA') {
        this.pagosService.deudaGlobal.set(notif['nueva_deuda']);
      }
    });
  }

  ngOnDestroy() {
    if (this.wsSubscription) {
      this.wsSubscription.unsubscribe();
    }
  }

  toggleSidebar() {
    this.isSidebarOpen = !this.isSidebarOpen;
  }

  toggleProfileMenu() {
    this.isProfileMenuOpen = !this.isProfileMenuOpen;
  }

  closeProfileMenu() {
    this.isProfileMenuOpen = false;
  }

  closeSidebarOnMobile() {
    if (window.innerWidth < 768) {
      this.isSidebarOpen = false;
    }
  }

  logout() {
    this.authService.logout();
  }

  resetNotifications() {
    this.notificationCount.set(0);
  }
}
