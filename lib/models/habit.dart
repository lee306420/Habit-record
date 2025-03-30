import '../utils/enums.dart';

class Habit {
  String name;
  HabitType type;
  bool completed;
  double value;
  String unit;
  Map<DateTime, dynamic> history;

  Habit({
    required this.name,
    required this.type,
    this.completed = false,
    this.value = 0,
    this.unit = '',
    Map<DateTime, dynamic>? history,
  }) : history = history ?? {};

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.index,
      'completed': completed,
      'value': value,
      'unit': unit,
      'history': history.map(
        (key, value) => MapEntry(key.toIso8601String(), value),
      ),
    };
  }

  factory Habit.fromJson(Map<String, dynamic> json) {
    final habit = Habit(
      name: json['name'],
      type: HabitType.values[json['type']],
      completed: json['completed'],
      value: (json['value'] ?? 0).toDouble(),
      unit: json['unit'],
      history: (json['history'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          DateTime.parse(key),
          HabitType.values[json['type']] == HabitType.boolean
              ? value as bool
              : (value ?? 0).toDouble(),
        ),
      ),
    );

    // 更新布尔类型习惯的今日完成状态
    if (habit.type == HabitType.boolean) {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      habit.completed = habit.history[today] == true;
    }
    // 更新可量化类型习惯的今日值
    else if (habit.type == HabitType.quantifiable) {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      if (habit.history.containsKey(today)) {
        habit.value = habit.history[today] as double;
      }
    }

    return habit;
  }

  List<String> toCsvRows() {
    final rows = <String>[];
    rows.add('日期,${type == HabitType.boolean ? "完成情况" : "数值"}');

    final sortedDates = history.keys.toList()..sort();

    for (final date in sortedDates) {
      final value = history[date];
      final formattedDate = '${date.year}-${date.month}-${date.day}';
      if (type == HabitType.boolean) {
        rows.add('$formattedDate,${value == true ? "是" : "否"}');
      } else {
        rows.add('$formattedDate,$value');
      }
    }

    return rows;
  }

  void addRecord(DateTime date, dynamic value) {
    final key = DateTime(date.year, date.month, date.day);
    if (type == HabitType.quantifiable && value is double) {
      history[key] = value;

      // 更新当前value值
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      // 如果是今天的记录，同步更新value属性
      if (key.year == today.year &&
          key.month == today.month &&
          key.day == today.day) {
        this.value = value;
      }
    } else {
      history[key] = value;
    }

    if (type == HabitType.boolean &&
        key ==
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            )) {
      completed = value == true;
    }
  }

  double getCompletionRate(DateTime startDate, DateTime endDate) {
    // 计算总天数（范围内的所有天数）
    final difference = endDate.difference(startDate).inDays + 1;
    final totalDays = difference;
    int completedDays = 0;

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (history.containsKey(key)) {
        if (type == HabitType.boolean) {
          if (history[key] == true) completedDays++;
        } else {
          if ((history[key] as double) > 0) completedDays++;
        }
      }
    }

    return totalDays == 0 ? 0 : completedDays / totalDays;
  }

  String getValueString(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    if (!history.containsKey(key)) return '-';

    if (type == HabitType.boolean) {
      return history[key] ? '✓' : '✗';
    } else {
      final value = history[key] as double;
      return '${value.toStringAsFixed(1)}$unit';
    }
  }

  bool get todayCompleted {
    if (type != HabitType.boolean) return false;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return history[today] == true;
  }
}
