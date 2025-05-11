import 'dart:math';

enum Role {
  mafia,
  doctor,
  detective,
  maniac,
  villager,
}

class Player {
  final String name;
  final Role role;
  final bool isAlive;

  Player({
    required this.name,
    required this.role,
    this.isAlive = true,
  });

  Player copyWith({
    String? name,
    Role? role,
    bool? isAlive,
  }) {
    return Player(
      name: name ?? this.name,
      role: role ?? this.role,
      isAlive: isAlive ?? this.isAlive,
    );
  }

  static Role assignRole(int gamesPlayed) {
    List<Role> activeRoles = [
      Role.mafia,
      Role.doctor,
      Role.detective,
      Role.maniac,
    ];

    List<Role> allRoles = [
      Role.mafia,
      Role.doctor,
      Role.detective,
      Role.maniac,
      Role.villager,
      Role.villager,
      Role.villager,
    ];

    final random = Random();

    if (gamesPlayed < 3) {
      return activeRoles[random.nextInt(activeRoles.length)];
    } else {
      return allRoles[random.nextInt(allRoles.length)];
    }
  }

  String get roleName {
    switch (role) {
      case Role.mafia:
        return "Мафия";
      case Role.doctor:
        return "Доктор";
      case Role.detective:
        return "Комиссар";
      case Role.maniac:
        return "Маньяк";
      case Role.villager:
        return "Мирный";
    }
  }

  bool get isActiveRole {
    return role == Role.mafia ||
        role == Role.doctor ||
        role == Role.detective ||
        role == Role.maniac;
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      name: map['name'],
      role: Role.values.firstWhere((r) => r.name == map['role']),
      isAlive: map['isAlive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role.name,
      'isAlive': isAlive,
    };
  }
}
