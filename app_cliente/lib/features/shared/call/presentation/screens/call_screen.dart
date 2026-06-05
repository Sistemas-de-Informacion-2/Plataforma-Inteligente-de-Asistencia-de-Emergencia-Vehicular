import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/network/websocket_service.dart';
import '../../../../../core/theme/app_theme.dart';

class CallScreen extends StatefulWidget {
  final WebSocketService wsService;
  final String contactName;
  final int targetId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.wsService,
    required this.contactName,
    required this.targetId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late StreamSubscription _wsSub;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  bool _isDeclined = false;
  
  Timer? _callTimer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _listenWs();

    if (!widget.isIncoming) {
      // Send Call Offer
      widget.wsService.sendMessage({
        "type": "CALL_OFFER",
        "target_id": widget.targetId,
      });
    }
  }

  void _listenWs() {
    _wsSub = widget.wsService.messageStream.listen((msg) {
      final type = msg['type'];
      if (type == "CALL_ANSWER") {
        setState(() {
          _isConnected = true;
          _startTimer();
        });
      } else if (type == "CALL_DECLINE" || type == "CALL_END") {
        setState(() {
          _isDeclined = true;
        });
        _endCall();
      }
    });
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  void _endCall() {
    if (!_isDeclined) {
      widget.wsService.sendMessage({
        "type": "CALL_END",
        "target_id": widget.targetId,
      });
    }
    _pulseController.stop();
    _callTimer?.cancel();
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _acceptCall() {
    setState(() {
      _isConnected = true;
      _startTimer();
    });
    widget.wsService.sendMessage({
      "type": "CALL_ANSWER",
      "target_id": widget.targetId,
    });
  }

  void _declineCall() {
    widget.wsService.sendMessage({
      "type": "CALL_DECLINE",
      "target_id": widget.targetId,
    });
    _endCall();
  }

  String get _timeString {
    final m = (_seconds / 60).floor().toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _wsSub.cancel();
    _callTimer?.cancel();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.inkDark,
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.inkDark, AppTheme.backgroundColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Contact Name
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Status / Timer
                Text(
                  _isDeclined
                      ? "Llamada finalizada"
                      : _isConnected
                          ? _timeString
                          : widget.isIncoming
                              ? "Llamada entrante..."
                              : "Llamando...",
                  style: TextStyle(
                    color: _isConnected ? AppTheme.success : Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const Spacer(),
                
                // Avatar with Pulse
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isConnected && !_isDeclined)
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 150 + (_pulseController.value * 50),
                            height: 150 + (_pulseController.value * 50),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryColor.withValues(alpha: 0.2 - (_pulseController.value * 0.2)),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                        image: const DecorationImage(
                          image: AssetImage('assets/images/retro_mechanic.png'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Controls
                if (_isConnected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        isActive: _isMuted,
                        onTap: () {
                          setState(() => _isMuted = !_isMuted);
                        },
                      ),
                      const SizedBox(width: 30),
                      _buildControlButton(
                        icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
                        isActive: _isSpeaker,
                        onTap: () {
                          setState(() => _isSpeaker = !_isSpeaker);
                        },
                      ),
                    ],
                  ),
                  
                const SizedBox(height: 40),
                
                // Actions
                if (widget.isIncoming && !_isConnected && !_isDeclined)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.call_end,
                        color: AppTheme.danger,
                        onTap: _declineCall,
                        label: "Rechazar",
                      ),
                      _buildActionButton(
                        icon: Icons.call,
                        color: AppTheme.success,
                        onTap: _acceptCall,
                        label: "Aceptar",
                      ),
                    ],
                  )
                else
                  _buildActionButton(
                    icon: Icons.call_end,
                    color: AppTheme.danger,
                    onTap: _endCall,
                    label: "Colgar",
                  ),
                  
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.1),
        ),
        child: Icon(
          icon,
          color: isActive ? AppTheme.inkDark : Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
