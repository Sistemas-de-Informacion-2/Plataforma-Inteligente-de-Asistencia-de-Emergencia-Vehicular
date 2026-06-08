import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineBanner extends StatefulWidget {
  final VoidCallback? onOnline;
  const OfflineBanner({super.key, this.onOnline});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> with SingleTickerProviderStateMixin {
  late StreamSubscription<List<ConnectivityResult>> _subscription;
  bool _isOffline = false;
  bool _hasInitialized = false;
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _checkInitialConnectivity();

    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    if (!mounted) return;
    final isOffline = results.contains(ConnectivityResult.none) || results.isEmpty;
    if (isOffline != _isOffline) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = isOffline;
      });
      
      if (_isOffline) {
        _controller.forward();
        if (_hasInitialized) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La conexión se perdió, por favor conéctate a una red'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _controller.reverse();
        if (_hasInitialized && wasOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La conexión volvió, vuelves a tener internet'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onOnline?.call();
        }
      }
    }
    _hasInitialized = true;
  }

  @override
  void dispose() {
    _subscription.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offsetAnimation,
      child: Container(
        width: double.infinity,
        color: Colors.redAccent,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 8,
          left: 16,
          right: 16,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Sin conexión a internet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
