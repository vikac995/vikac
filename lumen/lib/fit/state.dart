import 'package:material_ui/material_ui.dart';

/// The little bit of made-up data Prism runs on, shared by its pages.
class FitState extends ChangeNotifier {
  int goal = 2400, eaten = 1030;
  double weight = 81.8;
  bool weighedToday = false;
  final List<bool> sets = <bool>[true, false, false, false];
  final List<(String, bool?)> habits = <(String, bool?)>[
    ('Morning weigh-in', null),
    ('Creatine', null),
    ('Ten minutes of stretching', null),
  ];

  int get left => goal - eaten;

  void eat(int kcal) {
    eaten += kcal;
    notifyListeners();
  }

  void weigh(double kg) {
    weight = kg;
    weighedToday = true;
    if (habits[0].$2 == null) {
      habits[0] = (habits[0].$1, true);
    }
    notifyListeners();
  }

  void mark(int i, bool? done) {
    habits[i] = (habits[i].$1, done);
    notifyListeners();
  }

  void touch() => notifyListeners();
}

final FitState fit = FitState();
