// lib/widgets/phase_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/game_phase.dart'; // Убедись, что путь корректен

class PhaseBanner extends StatelessWidget {
  final String phase;
  final int duration;

  const PhaseBanner({
    super.key,
    required this.phase,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final GamePhase currentPhase = GamePhase.values.firstWhere(
      (e) => e.name == phase,
      orElse: () => GamePhase.preparation,
    );
    final PhaseConfig config = phaseConfigs[currentPhase]!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Theme.of(context).primaryColor, // Или другой цвет
      child: Column(
        children: [
          Text(
            '${loc.phase}: ${config.title}', // "Фаза: Обсуждение"
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            '${loc.timeLeft}: $duration ${loc.seconds}', // "Осталось: 60 секунд"
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            config.description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
