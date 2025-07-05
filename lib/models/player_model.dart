// lib/models/player_model.dart
import '../models/role_enum.dart';

class Player {
  final String id;
  final String name;
  final Role role;
  final bool isAlive;
  final int likesReceived;
  final String countryCode;
  final String? avatarUrl;

  Player({
    required this.id,
    required this.name,
    required this.role,
    this.isAlive = true,
    this.likesReceived = 0,
    this.countryCode = '',
    this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role.name,
      'isAlive': isAlive,
      'likesReceived': likesReceived,
      'countryCode': countryCode,
      'avatarUrl': avatarUrl,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      role: Role.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => Role.villager,
      ),
      isAlive: map['isAlive'] ?? true,
      likesReceived: map['likesReceived'] ?? 0,
      countryCode: map['countryCode'] ?? '',
      avatarUrl: map['avatarUrl'],
    );
  }
  Player copyWith({
    String? id,
    String? name,
    Role? role,
    bool? isAlive,
    int? likesReceived,
    String? countryCode,
    String? avatarUrl,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
      likesReceived: likesReceived ?? this.likesReceived,
      countryCode: countryCode ?? this.countryCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
