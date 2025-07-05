// lib/models/game_phase.dart

enum GamePhase {
  preparation, // Подготовка
  discussion, // Обсуждение
  selfDefense, // Самооборона и выбор цели
  voting, // Голосование и изгнание
  night, // Ночь
  morning, // Утро
  results, // Показ результатов голосования
  gameOver, // Игра завершена
}

class PhaseConfig {
  final String title;
  final String description;
  final int durationSeconds;

  const PhaseConfig({
    required this.title,
    required this.description,
    required this.durationSeconds,
  });
}

const Map<GamePhase, PhaseConfig> phaseConfigs = {
  GamePhase.preparation: PhaseConfig(
    title: 'Подготовка',
    description: 'Распределение ролей (никто не раскрывает роль)',
    durationSeconds: 15,
  ),
  GamePhase.discussion: PhaseConfig(
    title: 'Обсуждение',
    description: 'Обсуждайте, анализируйте, задавайте вопросы',
    durationSeconds: 180,
  ),
  GamePhase.selfDefense: PhaseConfig(
    title: 'Самооборона и выбор цели',
    description:
        '45 секунд на каждого живого игрока для обвинений и выбора цели',
    durationSeconds: 45,
  ),
  GamePhase.voting: PhaseConfig(
    title: 'Голосование и изгнание',
    description:
        'Игрок с наибольшим числом голосов выбывает; последнее слово — 20 сек.',
    durationSeconds: 20,
  ),
  GamePhase.night: PhaseConfig(
    title: 'Ночь',
    description: 'Мафия выбирает жертву; доктор спасает; комиссар проверяет',
    durationSeconds: 30,
  ),
  GamePhase.morning: PhaseConfig(
    title: 'Утро',
    description: 'Объявление погибших и (по желанию) результаты комиссара',
    durationSeconds: 10,
  ),
  GamePhase.results: PhaseConfig(
    title: 'Результаты голосования',
    description: 'Показать, кто за кого голосовал и кто выбыл',
    durationSeconds: 15,
  ),
  GamePhase.gameOver: PhaseConfig(
    title: 'Игра завершена',
    description: 'Победа мирных / мафии / маньяка',
    durationSeconds: 0,
  ),
};
