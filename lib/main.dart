import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';

enum ViewType {
  daily,
  weekly,
  monthly,
}

enum ChartType {
  bar,
  line,
  pie,
}

enum HabitType {
  boolean,
  quantifiable,
}

class _ChartData {
  final DateTime date;
  final double value;

  _ChartData(this.date, this.value);
}

class _Stats {
  final int totalCount;
  final int totalValue;
  final int averageCount;
  final int averageValue;

  _Stats({
    required this.totalCount,
    required this.totalValue,
    required this.averageCount,
    required this.averageValue,
  });
}

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

    if (habit.type == HabitType.boolean) {
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      habit.completed = habit.history[today] == true;
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
      history[key] = value.round().toDouble();
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
    int totalDays = 0;
    int completedDays = 0;

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (history.containsKey(key)) {
        totalDays++;
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
      final intValue = (history[key] as double).round();
      return '$intValue$unit';
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

class HabitHistoryPage extends StatefulWidget {
  final Habit habit;
  final Function() onHabitUpdated;

  const HabitHistoryPage({
    super.key,
    required this.habit,
    required this.onHabitUpdated,
  });

  @override
  State<HabitHistoryPage> createState() => _HabitHistoryPageState();
}

class _HabitHistoryPageState extends State<HabitHistoryPage> {
  late DateTime startDate;
  late DateTime endDate;
  ViewType currentView = ViewType.daily;
  ChartType currentChartType = ChartType.bar;

  @override
  void initState() {
    super.initState();
    // 默认显示最近7天
    endDate = DateTime.now();
    startDate = endDate.subtract(const Duration(days: 6));
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
    }
  }

  void _changeViewType(ViewType newView) {
    setState(() {
      currentView = newView;
      // 根据视图类型调整时间范围
      endDate = DateTime.now();
      switch (newView) {
        case ViewType.daily:
          startDate = endDate.subtract(const Duration(days: 6)); // 显示最近7天
          break;
        case ViewType.weekly:
          startDate = endDate.subtract(const Duration(days: 28)); // 显示最近4周
          break;
        case ViewType.monthly:
          startDate = endDate.subtract(const Duration(days: 180)); // 显示最近6个月
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('选择图表类型'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.bar_chart),
                        title: const Text('柱状图'),
                        selected: currentChartType == ChartType.bar,
                        onTap: () {
                          setState(() {
                            currentChartType = ChartType.bar;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.show_chart),
                        title: const Text('折线图'),
                        selected: currentChartType == ChartType.line,
                        onTap: () {
                          setState(() {
                            currentChartType = ChartType.line;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.pie_chart),
                        title: const Text('饼图'),
                        selected: currentChartType == ChartType.pie,
                        onTap: () {
                          setState(() {
                            currentChartType = ChartType.pie;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => _exportHabitData(widget.habit),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<ViewType>(
                    segments: const [
                      ButtonSegment(
                        value: ViewType.daily,
                        label: Text('日'),
                        icon: Icon(Icons.calendar_view_day),
                      ),
                      ButtonSegment(
                        value: ViewType.weekly,
                        label: Text('周'),
                        icon: Icon(Icons.calendar_view_week),
                      ),
                      ButtonSegment(
                        value: ViewType.monthly,
                        label: Text('月'),
                        icon: Icon(Icons.calendar_view_month),
                      ),
                    ],
                    selected: {currentView},
                    onSelectionChanged: (Set<ViewType> selected) {
                      _changeViewType(selected.first);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    '${startDate.month}/${startDate.day}-${endDate.month}/${endDate.day}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _selectDateRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: _buildHabitCard(widget.habit),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    final completionRate = habit.getCompletionRate(startDate, endDate);
    final stats = _calculateStats(habit, startDate, endDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(habit.name),
          subtitle: Text(
            habit.type == HabitType.boolean ? '完成与否' : '可量化的',
          ),
          trailing: CircularProgressIndicator(
            value: completionRate,
            backgroundColor: Colors.grey[200],
            strokeWidth: 8,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    currentView == ViewType.daily
                        ? '每日记录'
                        : currentView == ViewType.weekly
                            ? '每周统计'
                            : '每月统计',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '完成率: ${(completionRate * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 添加统计数据行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('总次数', '${stats.totalCount}次'),
                  if (habit.type == HabitType.quantifiable)
                    _buildStatItem(
                        '累计${habit.unit}', stats.totalValue.toString()),
                  _buildStatItem(
                    '平均每${currentView == ViewType.daily ? "天" : currentView == ViewType.weekly ? "周" : "月"}',
                    habit.type == HabitType.boolean
                        ? '${stats.averageCount}%'
                        : '${stats.averageValue}${habit.unit}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: _buildChart(habit),
              ),
              if (currentView == ViewType.daily) ...[
                const SizedBox(height: 16),
                _buildDailyView(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 添加统计项小部件
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // 添加图表构建方法
  Widget _buildChart(Habit habit) {
    final data = _getChartData(habit);

    switch (currentChartType) {
      case ChartType.bar:
        return _buildBarChart(data, habit);
      case ChartType.line:
        return _buildLineChart(data, habit);
      case ChartType.pie:
        return _buildPieChart(data, habit);
    }
  }

  Widget _buildBarChart(List<_ChartData> data, Habit habit) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        final maxValue = data.fold<double>(
          0,
          (max, item) => item.value > max ? item.value : max,
        );
        final height = maxValue == 0 ? 0 : (item.value / maxValue);

        String valueText;
        if (habit.type == HabitType.boolean) {
          valueText = currentView == ViewType.daily
              ? (item.value > 0 ? '完成' : '未完成')
              : '${item.value.toStringAsFixed(0)}次';
        } else {
          valueText = '${item.value.toStringAsFixed(1)}${habit.unit}';
        }

        return Container(
          width: currentView == ViewType.daily ? 40 : 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: currentView == ViewType.daily ? 20 : 40,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    height: height * 150,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                currentView == ViewType.daily
                    ? '${item.date.day}日'
                    : currentView == ViewType.weekly
                        ? '第${_getWeekNumber(item.date)}周'
                        : '${item.date.month}月',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLineChart(List<_ChartData> data, Habit habit) {
    if (data.isEmpty) return const Center(child: Text('暂无数据'));

    final spots = data.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < data.length) {
                  final date = data[value.toInt()].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      currentView == ViewType.daily
                          ? '${date.day}日'
                          : currentView == ViewType.weekly
                              ? '${_getWeekNumber(date)}周'
                              : '${date.month}月',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final date = data[touchedSpot.x.toInt()].date;
                final value = touchedSpot.y;
                String text;
                if (habit.type == HabitType.boolean) {
                  text = currentView == ViewType.daily
                      ? (value > 0 ? '完成' : '未完成')
                      : '${value.toStringAsFixed(0)}次';
                } else {
                  text = '${value.toStringAsFixed(1)}${habit.unit}';
                }
                return LineTooltipItem(
                  '${date.month}/${date.day}\n$text',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(List<_ChartData> data, Habit habit) {
    if (data.isEmpty) return const Center(child: Text('暂无数据'));

    final sections = <PieChartSectionData>[];

    if (habit.type == HabitType.boolean) {
      int completed = 0;
      int uncompleted = 0;
      for (var item in data) {
        if (item.value > 0) {
          completed++;
        } else {
          uncompleted++;
        }
      }

      if (completed > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.green,
            value: completed.toDouble(),
            title: '完成\n$completed次',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }

      if (uncompleted > 0) {
        sections.add(
          PieChartSectionData(
            color: Colors.red,
            value: uncompleted.toDouble(),
            title: '未完成\n$uncompleted次',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    } else {
      final values = data.map((e) => e.value).where((v) => v > 0).toList();
      if (values.isEmpty) {
        sections.add(
          PieChartSectionData(
            color: Colors.grey,
            value: 1,
            title: '暂无数据',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      } else {
        values.sort();
        final min = values.first;
        final max = values.last;
        final range = max - min;
        final sectionCount = 4; // 将数据分为4个区间

        if (range > 0) {
          final sectionsData = List.generate(sectionCount, (i) {
            final start = min + (range / sectionCount * i);
            final end = min + (range / sectionCount * (i + 1));
            final count = values.where((v) => v >= start && v < end).length;
            return {
              'start': start,
              'end': end,
              'count': count,
            };
          });

          final colors = [
            Colors.blue,
            Colors.green,
            Colors.orange,
            Colors.purple,
          ];

          sections.addAll(
            sectionsData.asMap().entries.map(
              (entry) {
                final i = entry.key;
                final section = entry.value;
                return PieChartSectionData(
                  color: colors[i],
                  value: section['count']!.toDouble(),
                  title:
                      '${section['start']!.toStringAsFixed(1)}-${section['end']!.toStringAsFixed(1)}${habit.unit}\n${section['count']}次',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              },
            ),
          );
        } else {
          sections.add(
            PieChartSectionData(
              color: Colors.blue,
              value: values.length.toDouble(),
              title: '${values.first}${habit.unit}\n${values.length}次',
              radius: 80,
              titleStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          );
        }
      }
    }

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 0,
        sectionsSpace: 2,
      ),
    );
  }

  // 添加获取周数的辅助方法
  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).ceil();
  }

  // 添加统计计算方法
  _Stats _calculateStats(Habit habit, DateTime startDate, DateTime endDate) {
    int totalCount = 0;
    double totalValue = 0;

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (habit.history.containsKey(key)) {
        totalCount++;
        if (habit.type == HabitType.boolean) {
          if (habit.history[key] == true) totalValue++;
        } else {
          totalValue += habit.history[key] as double;
        }
      }
    }

    final days = endDate.difference(startDate).inDays + 1;

    return _Stats(
      totalCount: totalCount,
      totalValue: totalValue.round(),
      averageCount: ((totalCount / days) * 100).round(),
      averageValue: totalCount > 0 ? (totalValue / totalCount).round() : 0,
    );
  }

  // 添加图表数据获取方法
  List<_ChartData> _getChartData(Habit habit) {
    switch (currentView) {
      case ViewType.daily:
        return _getDailyData(habit);
      case ViewType.weekly:
        return _getWeeklyData(habit);
      case ViewType.monthly:
        return _getMonthlyData(habit);
    }
  }

  List<_ChartData> _getDailyData(Habit habit) {
    final data = <_ChartData>[];
    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (habit.history.containsKey(key)) {
        final value = habit.type == HabitType.boolean
            ? (habit.history[key] == true ? 1.0 : 0.0)
            : (habit.history[key] as double);
        data.add(_ChartData(date, value));
      } else {
        data.add(_ChartData(date, 0));
      }
    }
    return data;
  }

  List<_ChartData> _getWeeklyData(Habit habit) {
    final weeklyData = <DateTime, List<double>>{};

    // 遍历日期范围内的每一天
    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      // 获取该周的周一作为 key
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final key = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final dayKey = DateTime(date.year, date.month, date.day);

      // 初始化该周的数据列表
      weeklyData[key] ??= [];

      // 添加当天的数据
      if (habit.history.containsKey(dayKey)) {
        final value = habit.type == HabitType.boolean
            ? (habit.history[dayKey] == true ? 1.0 : 0.0)
            : (habit.history[dayKey] as double);
        weeklyData[key]!.add(value);
      }
    }

    // 计算每周的统计数据
    return weeklyData.entries.map((entry) {
      final values = entry.value;
      if (values.isEmpty) return _ChartData(entry.key, 0);

      if (habit.type == HabitType.boolean) {
        // 布尔型习惯：计算完成次数
        final completedDays = values.where((v) => v > 0).length;
        return _ChartData(entry.key, completedDays.toDouble());
      } else {
        // 可量化习惯：计算总和
        final sum = values.reduce((a, b) => a + b);
        return _ChartData(entry.key, sum);
      }
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<_ChartData> _getMonthlyData(Habit habit) {
    final monthlyData = <DateTime, List<double>>{};

    // 遍历日期范围内的每一天
    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      // 获取该月的第一天作为 key
      final monthStart = DateTime(date.year, date.month, 1);
      final dayKey = DateTime(date.year, date.month, date.day);

      // 初始化该月的数据列表
      monthlyData[monthStart] ??= [];

      // 添加当天的数据
      if (habit.history.containsKey(dayKey)) {
        final value = habit.type == HabitType.boolean
            ? (habit.history[dayKey] == true ? 1.0 : 0.0)
            : (habit.history[dayKey] as double);
        monthlyData[monthStart]!.add(value);
      }
    }

    // 计算每月的统计数据
    return monthlyData.entries.map((entry) {
      final values = entry.value;
      if (values.isEmpty) return _ChartData(entry.key, 0);

      if (habit.type == HabitType.boolean) {
        // 布尔型习惯：计算完成次数
        final completedDays = values.where((v) => v > 0).length;
        return _ChartData(entry.key, completedDays.toDouble());
      } else {
        // 可量化习惯：计算总和
        final sum = values.reduce((a, b) => a + b);
        return _ChartData(entry.key, sum);
      }
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  // 添加每日视图构建方法
  Widget _buildDailyView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (DateTime date = startDate;
                date.isBefore(endDate.add(const Duration(days: 1)));
                date = date.add(const Duration(days: 1)))
              GestureDetector(
                onTap: () => _showEditHistoryDialog(widget.habit, date),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[200]!,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${date.month}月${date.day}日',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: widget.habit.history.containsKey(date)
                              ? widget.habit.type == HabitType.boolean
                                  ? widget.habit.history[date] == true
                                      ? Colors.green[50]
                                      : Colors.red[50]
                                  : Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.habit.history.containsKey(date)
                                ? widget.habit.type == HabitType.boolean
                                    ? widget.habit.history[date] == true
                                        ? Colors.green[200]!
                                        : Colors.red[200]!
                                    : Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.3)
                                : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.habit.getValueString(date),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: widget.habit.history.containsKey(date)
                                ? widget.habit.type == HabitType.boolean
                                    ? widget.habit.history[date] == true
                                        ? Colors.green[700]
                                        : Colors.red[700]
                                    : Theme.of(context).primaryColor
                                : Colors.grey[400],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ['日', '一', '二', '三', '四', '五', '六'][date.weekday % 7],
                        style: TextStyle(
                          color: date.weekday == DateTime.sunday ||
                                  date.weekday == DateTime.saturday
                              ? Colors.blue[300]
                              : Colors.grey[500],
                          fontSize: 12,
                          fontWeight: date.weekday == DateTime.sunday ||
                                  date.weekday == DateTime.saturday
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 添加编辑历史记录的对话框
  Future<void> _showEditHistoryDialog(Habit habit, DateTime date) async {
    final valueController = TextEditingController();
    if (habit.type == HabitType.boolean) {
      valueController.text = habit.history[date] == true ? '1' : '0';
    } else {
      valueController.text = (habit.history[date] ?? '').toString();
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.year}年${date.month}月${date.day}日',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              habit.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: habit.type == HabitType.boolean
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusButton(
                      icon: Icons.close_rounded,
                      label: '未完成',
                      isSelected: habit.history[date] == false,
                      color: Colors.red.shade400,
                      onPressed: () {
                        setState(() {
                          habit.addRecord(date, false);
                        });
                        widget.onHabitUpdated();
                        Navigator.pop(context);
                      },
                    ),
                    _buildStatusButton(
                      icon: Icons.check_rounded,
                      label: '已完成',
                      isSelected: habit.history[date] == true,
                      color: Colors.green.shade400,
                      onPressed: () {
                        setState(() {
                          habit.addRecord(date, true);
                        });
                        widget.onHabitUpdated();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: valueController,
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '完成数值',
                        suffixText: habit.unit,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Theme.of(context).primaryColor,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          if (habit.history.containsKey(date))
            TextButton.icon(
              onPressed: () {
                setState(() {
                  habit.history.remove(date);
                });
                widget.onHabitUpdated();
                Navigator.pop(context);
              },
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              label: Text(
                '删除记录',
                style: TextStyle(color: Colors.red[400]),
              ),
            ),
          const SizedBox(width: 8),
          if (habit.type == HabitType.quantifiable)
            FilledButton(
              onPressed: () {
                final value = double.tryParse(valueController.text);
                if (value != null) {
                  setState(() {
                    habit.addRecord(date, value);
                  });
                  widget.onHabitUpdated();
                  Navigator.pop(context);
                }
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('保存'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 修改单个习惯的导出方法
  Future<void> _exportHabitData(Habit habit) async {
    try {
      // 创建 CSV 内容
      final csvRows = habit.toCsvRows();
      final csvContent = csvRows.join('\n');

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${habit.name}_记录_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      // 写入文件
      await file.writeAsString(csvContent, flush: true);

      // 分享文件
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '${habit.name}的记录数据',
        ).then((_) {
          // 分享完成后删除临时文件
          file.delete().catchError((e) {
            debugPrint('删除临时文件失败: $e');
          });
        }).catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分享失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    // 请求所有必要的权限
    await [
      Permission.storage,
      Permission.notification,
    ].request();

    // Android 10及以上需要特殊处理
    if (await Permission.storage.isGranted) {
      await Permission.manageExternalStorage.request();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '习惯打卡',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Habit> habits = [];
  final String _storageKey = 'habits';
  String? _customStoragePath;

  Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;

      if (androidVersion >= 30) {
        // Android 11 及以上
        await [
          Permission.notification,
        ].request();

        // 对于文件管理权限，需要引导用户到系统设置
        if (!await Permission.manageExternalStorage.isGranted) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('需要"所有文件访问权限"'),
                content: const Text('请在系统设置中开启"允许管理所有文件"的权限，否则可能无法正常访问文件。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await openAppSettings();
                    },
                    child: const Text('去设置'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        // Android 10 及以下
        await [
          Permission.storage,
          Permission.notification,
        ].request();
      }

      // 检查权限状态并显示提示
      final deniedPermissions = await Future.wait([
        Permission.notification,
        androidVersion >= 30
            ? Permission.manageExternalStorage
            : Permission.storage,
      ].map((permission) async {
        final status = await permission.status;
        return status.isDenied ? permission : null;
      }));

      final filteredDeniedPermissions =
          deniedPermissions.whereType<Permission>().toList();

      if (filteredDeniedPermissions.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('需要必要权限'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('此应用需要以下权限才能正常运行：'),
                const SizedBox(height: 8),
                ...filteredDeniedPermissions.map((permission) => Text(
                      '• ${_getPermissionDescription(permission)}',
                      style: const TextStyle(fontSize: 14),
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: const Text('去设置'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.storage:
        return '存储权限 - 用于保存应用数据';
      case Permission.notification:
        return '通知权限 - 用于发送提醒通知';
      case Permission.manageExternalStorage:
        return '文件管理权限 - 用于管理应用数据';
      default:
        return permission.toString();
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadCustomStoragePath().then((_) => _loadHabits());
  }

  Future<void> _loadHabits() async {
    try {
      final storagePath = await _getStoragePath();
      final file = File('$storagePath/habits.json');

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final habitsList = jsonDecode(content) as List;
          setState(() {
            habits = habitsList
                .map((json) => Habit.fromJson(json as Map<String, dynamic>))
                .toList();
          });
        }
      }
    } catch (e) {
      debugPrint('加载数据失败: $e');
    }
  }

  Future<void> _saveHabits() async {
    try {
      final storagePath = await _getStoragePath();
      debugPrint('保存数据到路径: $storagePath');

      final directory = Directory(storagePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('$storagePath/habits.json');
      final habitsJson = jsonEncode(habits.map((h) => h.toJson()).toList());
      await file.writeAsString(habitsJson, flush: true);
      debugPrint('数据保存成功');
    } catch (e) {
      debugPrint('保存数据失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存数据失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleHabit(int index) {
    setState(() {
      if (habits[index].type == HabitType.boolean) {
        final newValue = !habits[index].completed;
        habits[index].completed = newValue;
        habits[index].addRecord(DateTime.now(), newValue);
        _saveHabits();
      }
    });
  }

  void _updateQuantifiableHabit(int index, double value) {
    setState(() {
      if (habits[index].type == HabitType.quantifiable) {
        habits[index].value = value;
        habits[index].addRecord(DateTime.now(), value);
        _saveHabits();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '我的习惯',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportAllData();
                  break;
                case 'import':
                  _importData();
                  break;
                case 'setStoragePath':
                  _showSetStoragePathDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 12),
                    Text('导出所有数据'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('导入数据'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'setStoragePath',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.folder),
                        SizedBox(width: 12),
                        Text('设置数据存储路径'),
                      ],
                    ),
                    FutureBuilder<String>(
                      future: _getStoragePath(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: 32, top: 4),
                          child: Text(
                            _getDisplayPath(snapshot.data!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: habits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.note_add,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '还没有添加习惯',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddHabitDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加一个习惯'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: habits.length,
              itemBuilder: (context, index) {
                final habit = habits[index];
                return Dismissible(
                  key: Key(habit.name),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '删除',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text('确定要删除"${habit.name}"及其所有记录吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    setState(() {
                      habits.removeAt(index);
                    });
                    _saveHabits();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已删除"${habit.name}"'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onDoubleTap: () {
                        _showHabitHistory(habit);
                      },
                      onLongPress: () {
                        _showEditHabitNameDialog(habit);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                habit.type == HabitType.boolean
                                    ? Icons.check_circle_outline
                                    : Icons.trending_up,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    habit.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '双击查看统计 · 长按修改名称',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (habit.type == HabitType.boolean)
                              Transform.scale(
                                scale: 1.1,
                                child: Checkbox(
                                  value: habit.todayCompleted,
                                  onChanged: (_) => _toggleHabit(index),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${habit.value} ${habit.unit}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () =>
                                        _showQuantityDialog(context, index),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddHabitDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('添加习惯'),
      ),
    );
  }

  Future<void> _showQuantityDialog(BuildContext context, int index) async {
    final controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('输入${habits[index].name}的数值'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '数值',
            suffixText: habits[index].unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                _updateQuantifiableHabit(index, value);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddHabitDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    HabitType selectedType = HabitType.boolean;

    return showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '添加新习惯',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: const EdgeInsets.all(4),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '习惯名称',
                    hintText: '例如：早起、跑步等',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.edit),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButtonFormField<HabitType>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: '习惯类型',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                      items: [
                        DropdownMenuItem(
                          value: HabitType.boolean,
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.blue[400]),
                              const SizedBox(width: 8),
                              const Text('完成与否'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: HabitType.quantifiable,
                          child: Row(
                            children: [
                              Icon(Icons.trending_up, color: Colors.blue[400]),
                              const SizedBox(width: 8),
                              const Text('可量化的'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ),
                ),
                if (selectedType == HabitType.quantifiable) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: '单位',
                      hintText: '例如：公里、页等',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.straighten),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      setState(() {
                        habits.add(
                          Habit(
                            name: nameController.text,
                            type: selectedType,
                            unit: unitController.text,
                          ),
                        );
                      });
                      _saveHabits();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '添加习惯',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportAllData() async {
    try {
      final data = habits.map((h) => h.toJson()).toList();
      final jsonContent = jsonEncode(data);

      // 使用自定义路径或默认路径
      final directory = _customStoragePath != null
          ? Directory(_customStoragePath!)
          : await getApplicationDocumentsDirectory();

      final fileName =
          'habits_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${directory.path}/$fileName');

      // 写入文件
      await file.writeAsString(jsonContent, flush: true);

      // 分享文件
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: '习惯记录数据备份').then((_) {
          // 如果是默认路径则删除临时文件
          if (_customStoragePath == null) {
            file.delete().catchError((e) {
              debugPrint('删除临时文件失败: $e');
            });
          }
        }).catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('分享失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导出失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      // 显示导入说明对话框
      final confirmResult = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入数据'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('请选择之前导出的 JSON 文件'),
              SizedBox(height: 8),
              Text(
                '注意：导入数据将覆盖当前所有数据！',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('继续'),
            ),
          ],
        ),
      );

      if (confirmResult != true) return;

      // 选择文件
      final pickerResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (pickerResult == null || pickerResult.files.isEmpty) return;

      // 读取文件内容
      final filePath = pickerResult.files.first.path;
      if (filePath == null) {
        throw Exception('无法获取文件路径');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('文件不存在');
      }

      final jsonString = await file.readAsString();
      if (jsonString.isEmpty) {
        throw Exception('文件内容为空');
      }

      // 解析数据
      final List<dynamic> data = jsonDecode(jsonString);
      final newHabits = data
          .map((json) => Habit.fromJson(json as Map<String, dynamic>))
          .toList();

      // 更新数据
      setState(() {
        habits = newHabits;
      });
      await _saveHabits();

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据导入成功！'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败：${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadCustomStoragePath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customStoragePath = prefs.getString('custom_storage_path');
    });
  }

  Future<void> _saveCustomStoragePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_storage_path', path);
    setState(() {
      _customStoragePath = path;
    });
  }

  Future<String> _getStoragePath() async {
    if (_customStoragePath != null) {
      final directory = Directory(_customStoragePath!);
      if (await directory.exists()) {
        return _customStoragePath!;
      }
    }
    final defaultDir = await getApplicationDocumentsDirectory();
    return defaultDir.path;
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // 获取 Android 版本
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;

      if (androidVersion >= 30) {
        // Android 11 及以上需要 MANAGE_EXTERNAL_STORAGE 权限
        if (!await Permission.manageExternalStorage.isGranted) {
          // 显示说明对话框
          if (mounted) {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('需要"所有文件访问权限"'),
                content: const Text(
                    '由于 Android 系统限制，需要在系统设置中手动开启"允许管理所有文件"权限，否则无法自定义存储路径。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('去设置'),
                  ),
                ],
              ),
            );

            if (result == true) {
              await openAppSettings();
              // 等待用户从设置页面返回
              await Future.delayed(const Duration(seconds: 1));
              // 重新检查权限
              return await Permission.manageExternalStorage.isGranted;
            }
            return false;
          }
        }
        return true;
      } else {
        // Android 10 及以下使用普通存储权限
        return await Permission.storage.isGranted;
      }
    }
    // iOS 默认返回 true
    return true;
  }

  Future<void> _showSetStoragePathDialog() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final androidVersion = androidInfo.version.sdkInt;

      if (androidVersion >= 30 &&
          !await Permission.manageExternalStorage.isGranted) {
        // 先请求 MANAGE_EXTERNAL_STORAGE 权限
        if (!await _requestStoragePermission()) {
          return;
        }
      } else if (!await Permission.storage.isGranted) {
        // Android 10 及以下版本请求普通存储权限
        if (!await _requestStoragePermission()) {
          return;
        }
      }
    }

    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择数据存储目录',
      );

      if (selectedDirectory == null) return;

      // 验证目录权限
      try {
        final testFile = File('$selectedDirectory/test.tmp');
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法在选择的目录中写入数据，请选择其他目录'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 保存新路径
      await _saveCustomStoragePath(selectedDirectory);

      // 将现有数据移动到新位置
      await _moveDataToNewLocation(selectedDirectory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已设置数据存储路径: $selectedDirectory'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置存储路径失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveDataToNewLocation(String newPath) async {
    try {
      final oldPath = (await getApplicationDocumentsDirectory()).path;
      final oldFile = File('$oldPath/habits.json');

      if (await oldFile.exists()) {
        final newFile = File('$newPath/habits.json');
        await oldFile.copy(newFile.path);
        await oldFile.delete();
      }

      // 重新加载数据
      await _loadHabits();
    } catch (e) {
      debugPrint('移动数据失败: $e');
    }
  }

  String _getDisplayPath(String path) {
    if (Platform.isIOS) {
      // iOS 显示相对路径
      final parts = path.split('/');
      return '.../${parts.last}';
    }
    // Android 显示完整路径
    return path;
  }

  void _showHabitHistory(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitHistoryPage(
          habit: habit,
          onHabitUpdated: _saveHabits,
        ),
      ),
    );
  }

  Future<void> _showEditHabitNameDialog(Habit habit) async {
    final nameController = TextEditingController(text: habit.name);

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改习惯名称'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: '习惯名称',
            hintText: '例如：早起、跑步等',
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.edit),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                setState(() {
                  habit.name = nameController.text;
                });
                _saveHabits();
                Navigator.pop(context);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
