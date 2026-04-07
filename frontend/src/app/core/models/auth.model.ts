export type Role = 'ADMINISTRADOR' | 'PERSONAL' | 'CLIENTE';

export interface User {
  id: string;
  name: string;
  email: string;
  role: Role;
}

export interface AuthResponse {
  user: User;
  token: string;
}

export interface LoginCredentials {
  email: string;
  password: string;
}
