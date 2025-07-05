// lib/widgets/player_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/player_model.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/role_enum.dart';
import 'package:cached_network_image/cached_network_image.dart'; // НОВЫЙ ИМПОРТ для кэширования

class PlayerCard extends StatelessWidget {
  final Player player;
  final bool isCurrentUser;
  final RTCVideoRenderer? rtcRenderer;
  final bool isMicOn;
  final bool isCamOn;
  final VoidCallback? onTap;

  const PlayerCard({
    super.key,
    required this.player,
    this.isCurrentUser = false,
    this.rtcRenderer,
    this.isMicOn = true,
    this.isCamOn = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool isAlive = player.isAlive;
    final Color cardColor = isCurrentUser
        ? Colors.blue.shade700
        : (isAlive ? Colors.grey.shade800 : Colors.grey.shade900);

    return Card(
      color: cardColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isCurrentUser
            ? const BorderSide(color: Colors.yellow, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isAlive ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (rtcRenderer != null &&
                        rtcRenderer!.textureId != null &&
                        rtcRenderer!.srcObject != null &&
                        isCamOn &&
                        isAlive)
                      RTCVideoView(rtcRenderer!,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
                    // Отображаем аватар или инициалы, если камера выключена, или игрок мертв, или нет видеопотока
                    if (!isCamOn || !isAlive || rtcRenderer?.srcObject == null)
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueGrey,
                        // Использование CachedNetworkImageProvider для аватара
                        backgroundImage: player.avatarUrl != null
                            ? CachedNetworkImageProvider(player.avatarUrl!)
                            : null,
                        child: player.avatarUrl ==
                                null // Показываем инициалы, если аватара нет
                            ? Text(
                                player.name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              )
                            : null, // Иначе не показываем дочерний элемент
                      ),
                    if (!isAlive)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black54,
                          child: Center(
                            child: Text(loc.eliminated,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    if (!isMicOn && isAlive)
                      const Positioned(
                        top: 4,
                        left: 4,
                        child: Icon(Icons.mic_off,
                            color: Colors.redAccent, size: 20),
                      ),
                    if (!isCamOn && isAlive)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.videocam_off,
                            color: Colors.redAccent, size: 20),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                player.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isAlive ? Colors.white : Colors.red.shade200,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isCurrentUser)
                Column(
                  children: [
                    Text(
                      '(${loc.yourRole}: ${player.role.name})',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: player.role == Role.mafia
                            ? Colors.red.shade300
                            : Colors.green.shade300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRoleVisual(player.role, loc),
                  ],
                ),
              if (player.likesReceived > 0)
                Text(
                  '👍 ${player.likesReceived}',
                  style: const TextStyle(fontSize: 12, color: Colors.amber),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleVisual(Role role, AppLocalizations loc) {
    String assetPath;
    String roleText;
    Color bgColor;
    Color textColor = Colors.white;

    switch (role) {
      case Role.mafia:
        assetPath = 'assets/mafia_apk/images/mafia_icon.png';
        roleText = loc.mafiaRole;
        bgColor = Colors.red.shade700;
        break;
      case Role.doctor:
        assetPath = 'assets/mafia_apk/images/doctor_icon.png';
        roleText = loc.doctorRole;
        bgColor = Colors.blue.shade700;
        break;
      case Role.detective:
        assetPath = 'assets/mafia_apk/images/detective_icon.png';
        roleText = loc.detectiveRole;
        bgColor = Colors.purple.shade700;
        break;
      case Role.maniac:
        assetPath = 'assets/mafia_apk/images/maniac_icon.png';
        roleText = loc.maniacRole;
        bgColor = Colors.deepOrange.shade700;
        break;
      case Role.villager:
        assetPath = 'assets/mafia_apk/images/villager_icon.png';
        roleText = loc.villagerRole;
        bgColor = Colors.green.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            assetPath,
            width: 20,
            height: 20,
            color: textColor,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Ошибка загрузки иконки роли ($assetPath): $error');
              return Icon(Icons.help_outline, size: 20, color: textColor);
            },
          ),
          const SizedBox(width: 4),
          Text(
            roleText,
            style: TextStyle(
                color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
