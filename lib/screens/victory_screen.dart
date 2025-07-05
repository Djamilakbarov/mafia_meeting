import 'package:flutter/material.dart';

class VictoryScreen extends StatelessWidget {
  final String winnerTeam;
  final String? message;
  final VoidCallback onPlayAgain;

  const VictoryScreen({
    super.key,
    required this.winnerTeam,
    this.message,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMafia = winnerTeam == 'mafia';

    final String displayMessage =
        message ?? (isMafia ? '🩸 Mafia Wins!' : '🛡 Villagers Win!');
    final String detailMessage = isMafia
        ? 'The mafia eliminated all threats.'
        : 'The villagers defeated the mafia.';

    return Scaffold(
      backgroundColor: isMafia ? Colors.red.shade900 : Colors.green.shade800,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isMafia ? Icons.nightlight_round : Icons.wb_sunny,
                size: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 20),
              Text(
                displayMessage,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                detailMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: onPlayAgain,
                icon: const Icon(Icons.replay),
                label: const Text("Play Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: isMafia ? Colors.red : Colors.green,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
