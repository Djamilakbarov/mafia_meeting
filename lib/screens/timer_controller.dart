import 'dart:async';
import 'package:flutter/material.dart';

class TimerController extends ChangeNotifier {
  int _timeLeft = 0;
  Timer? _timer;

  int get timeLeft => _timeLeft;

  void start(int duration, VoidCallback onEnd) {
    _timer?.cancel();
    _timeLeft = duration;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _timeLeft--;
      notifyListeners();
      if (_timeLeft <= 0) {
        _timer?.cancel();
        onEnd();
      }
    });
  }

  void cancel() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
