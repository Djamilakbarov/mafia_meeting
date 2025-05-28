import '../models/role_enum.dart';

class Player {
  final String name;
  final Role role;
  final bool isAlive;
  final bool isBot;

  Player({
    required this.name,
    required this.role,
    this.isAlive = true,
    this.isBot = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role.name,
      'isAlive': isAlive,
      'isBot': isBot,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      name: map['name'],
      role: Role.values.firstWhere((r) => r.name == map['role']),
      isAlive: map['isAlive'] ?? true,
      isBot: map['isBot'] ?? false,
    );
  }
}
