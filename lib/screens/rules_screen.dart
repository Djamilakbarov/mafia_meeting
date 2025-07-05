import 'package:flutter/material.dart';

class RulesScreen extends StatelessWidget {
  static const routeName = '/rules';

  const RulesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Правила игры',
          style: TextStyle(
            fontFamily: 'Headliner',
            fontSize: 24,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/mafia_apk/images/city_grey.png'),
            fit: BoxFit.cover,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
        child: ListView(
          children: const [
            Text(
              '1. Ночь: все игроки закрывают глаза, ведущий вызывает мафию.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '2. Мафия бессимвольно выбирает жертву.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '3. Доктор может спасти одного игрока.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '4. Комиссар проверяет роль одного игрока.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '5. Утро: все просыпаются и узнают результат ночи.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '6. Обсуждение: игроки обсуждают и голосуют.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '7. Голосование: большинство решает, кого казнить.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
            SizedBox(height: 12),
            Text(
              '8. Игра продолжается, пока одна фракция не победит.',
              style: TextStyle(fontFamily: 'Geometria', fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
