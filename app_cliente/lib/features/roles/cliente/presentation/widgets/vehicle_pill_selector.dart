import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../data/models/vehiculo.dart';

// Widget selector de vehículo en forma de píldora flotante sobre el mapa.
// Diseño compacto con dropdown estilizado y badge de placa.
class VehiclePillSelector extends StatelessWidget {
  final List<Vehiculo> vehiculos;
  final Vehiculo? selected;
  final ValueChanged<Vehiculo?> onChanged;

  const VehiclePillSelector({
    super.key,
    required this.vehiculos,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: AppTheme.floatShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícono de vehículo
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              size: 16,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 10),

          // Selector / texto
          Expanded(
            child: vehiculos.isEmpty
                ? Text(
                    'Sin vehículos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Vehiculo>(
                      value: selected,
                      isExpanded: true,
                      isDense: true,
                      itemHeight: 60,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontFamily: 'Inter',
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      hint: const Text(
                        'Selecciona...',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Item seleccionado (vista cerrada)
                      selectedItemBuilder: (context) {
                        return vehiculos.map<Widget>((v) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${v.marca} ${v.modelo}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _PlacaTag(placa: v.placa),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                      // Items del dropdown
                      items: vehiculos.map((v) {
                        return DropdownMenuItem<Vehiculo>(
                          value: v,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                // Mini ícono
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${v.marca} ${v.modelo}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Año ${v.anio}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _PlacaTag(placa: v.placa, compact: false),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Badge de placa reutilizable
class _PlacaTag extends StatelessWidget {
  final String placa;
  final bool compact;

  const _PlacaTag({required this.placa, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        placa.toUpperCase(),
        style: TextStyle(
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
