import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MecanicoState { idle, sosRecibido, enRuta }

class MecanicoNotifier extends Notifier<MecanicoState> {
  @override
  MecanicoState build() {
    return MecanicoState.idle;
  }

  void receiveSos() {
    state = MecanicoState.sosRecibido;
  }

  void acceptJob() {
    state = MecanicoState.enRuta;
  }

  void rejectJob(String reason) {
    // TODO: Enviar la razón del rechazo al Admin vía WebSocket o API
    state = MecanicoState.idle;
  }

  void arriveAtLocation() {
    // TODO: Notificar llegada al backend
    state = MecanicoState.idle;
  }
}

final mecanicoControllerProvider = NotifierProvider<MecanicoNotifier, MecanicoState>(() {
  return MecanicoNotifier();
});

class IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }

  void setStatus(bool isOnline) {
    state = isOnline;
  }
}

final isOnlineProvider = NotifierProvider<IsOnlineNotifier, bool>(() {
  return IsOnlineNotifier();
});
