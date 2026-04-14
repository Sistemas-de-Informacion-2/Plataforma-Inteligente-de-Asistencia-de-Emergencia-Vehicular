import 'package:flutter/material.dart';
import 'package:app_cliente/core/theme/app_theme.dart';
import 'package:app_cliente/features/vehiculos/models/vehiculo.dart';

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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: AppTheme.glassPill(),
      child: Row(
        children: [
          const Icon(Icons.directions_car_rounded,
              size: 18, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: vehiculos.isEmpty
                ? Text(
                    'Sin vehículos',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<Vehiculo>(
                      value: selected,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.expand_more_rounded,
                          size: 18, color: AppTheme.textSecondary),
                      hint: const Text(
                        '¿Qué vehículo?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      onChanged: onChanged,
                      items: vehiculos
                          .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '${v.marca} ${v.modelo} · ${v.placa}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
