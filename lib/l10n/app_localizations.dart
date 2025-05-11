import 'package:flutter/widgets.dart';

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => AppLocalizations();

  // Строки интерфейса
  String get day1 => "Day 1";
  String get welcome => "Welcome";
  String get phase => "Phase";
  String get phaseDiscussion => "Discussion";
  String get phaseVoting => "Voting";
  String get phaseResult => "Results";
  String get choosePlayerToAccuse => "Choose a player to accuse:";
  String get player => "Player";
  String get skipDiscussion => "Skip discussion";
  String get accused => "Accused";
  String get yourVerdict => "Your verdict:";
  String get voteKill => "Vote to Kill";
  String get voteSpare => "Vote to Spare";
  String get votedToKill => "You voted to eliminate";
  String get votedToSpare => "You voted to spare";
  String get discussionSkipped => "Discussion skipped";
  String get voteResults => "Voting results.";
  String get nextDay => "Next day";
  String get lobby => "Lobby";
  String get createRoom => "Create Room";
  String get joinRoom => "Join Room";
  String get roomCode => "Room Code";
  String get players => "Players";
  String get startGame => "Start Game";
  String get invalidRoomCode => "Invalid room code";
  String get error => "Error";
  String get ok => "OK";
  String get leave => "Leave";

  // Дополнительно (если надо будет)
  String get settings => "Settings";
  String get language => "Language";
  String get theme => "Theme";
}
