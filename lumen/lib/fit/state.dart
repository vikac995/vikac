import 'package:material_ui/material_ui.dart';

/// The little bit of made-up data Prism runs on, shared by its pages.
class FitState extends ChangeNotifier {
  int goal = 2400;

  /// The day's meals: name, what is in it, kcal, protein, carbs, fat (g). [count] says how many were eaten.
  static const List<(String, String, int, int, int, int)> meals =
      <(String, String, int, int, int, int)>[
        ('Breakfast', 'Oats and banana', 420, 14, 72, 8),
        ('Lunch', 'Chicken and rice', 610, 48, 70, 12),
        ('Dinner', 'Salmon, potatoes', 680, 42, 55, 30),
        ('Snacks', 'Protein bar', 210, 20, 22, 7),
      ];
  final List<int> count = <int>[1, 1, 0, 0];

  int sum(int field) {
    int s = 0;
    for (int i = 0; i < meals.length; i++) {
      final (String, String, int, int, int, int) m = meals[i];
      s += count[i] * <int>[m.$3, m.$4, m.$5, m.$6][field];
    }
    return s;
  }

  int get eaten => sum(0);
  double weight = 81.8;
  bool weighedToday = false;
  final List<bool> sets = <bool>[true, false, false, false];
  final List<(String, bool?)> habits = <(String, bool?)>[
    ('Morning weigh-in', null),
    ('Creatine', null),
    ('Ten minutes of stretching', null),
  ];

  int get left => goal - eaten;

  void addMeal(int i, int by) {
    if (count[i] + by < 0) {
      return;
    }
    count[i] += by;
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
