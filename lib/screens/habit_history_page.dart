import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/habit.dart';
import '../models/chart_data.dart';
import '../utils/enums.dart';
import 'dart:math';
import 'package:intl/intl.dart';

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
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.date_range,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('选择日期范围'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDateRangeQuickButton('今天', () {
                  final now = DateTime.now();
                  setState(() {
                    startDate = now;
                    endDate = now;
                  });
                  Navigator.pop(context);
                }),
                _buildDateRangeQuickButton('最近7天', () {
                  final now = DateTime.now();
                  setState(() {
                    endDate = now;
                    startDate = now.subtract(const Duration(days: 6));
                  });
                  Navigator.pop(context);
                }),
                _buildDateRangeQuickButton('最近30天', () {
                  final now = DateTime.now();
                  setState(() {
                    endDate = now;
                    startDate = now.subtract(const Duration(days: 29));
                  });
                  Navigator.pop(context);
                }),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDateRangeQuickButton('本周', () {
                  final now = DateTime.now();
                  setState(() {
                    endDate = now;
                    startDate = now.subtract(Duration(days: now.weekday - 1));
                  });
                  Navigator.pop(context);
                }),
                _buildDateRangeQuickButton('本月', () {
                  final now = DateTime.now();
                  setState(() {
                    endDate = now;
                    startDate = DateTime(now.year, now.month, 1);
                  });
                  Navigator.pop(context);
                }),
                _buildDateRangeQuickButton('今年', () {
                  final now = DateTime.now();
                  setState(() {
                    endDate = now;
                    startDate = DateTime(now.year, 1, 1);
                  });
                  Navigator.pop(context);
                }),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_month),
              label: const Text('自定义范围'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange:
                      DateTimeRange(start: startDate, end: endDate),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: Theme.of(context).colorScheme.primary,
                          onPrimary: Colors.white,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );

                if (picked != null) {
                  setState(() {
                    startDate = picked.start;
                    endDate = picked.end;
                  });
                }
              },
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildDateRangeQuickButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        elevation: 0,
        textStyle: const TextStyle(fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
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
        title: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          child: Text(
            widget.habit.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '图表类型',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.bar_chart,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const Text('选择图表类型'),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.bar_chart,
                          color: currentChartType == ChartType.bar
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: const Text('柱状图'),
                        subtitle: const Text('显示每个时间段的数值'),
                        selected: currentChartType == ChartType.bar,
                        onTap: () {
                          setState(() {
                            currentChartType = ChartType.bar;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.show_chart,
                          color: currentChartType == ChartType.line
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: const Text('折线图'),
                        subtitle: const Text('显示数值变化趋势'),
                        selected: currentChartType == ChartType.line,
                        onTap: () {
                          setState(() {
                            currentChartType = ChartType.line;
                          });
                          Navigator.pop(context);
                        },
                      ),
                      ListTile(
                        leading: Icon(
                          Icons.pie_chart,
                          color: currentChartType == ChartType.pie
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        title: const Text('饼图'),
                        subtitle: const Text('显示数值分布情况'),
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
            tooltip: '导出数据',
            onPressed: () => _exportHabitData(widget.habit),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
            ],
          ),
        ),
        child: Column(
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
                    icon: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      '${startDate.year == endDate.year ? '' : '${startDate.year}/'}${startDate.month}/${startDate.day} - ${endDate.year == startDate.year ? '' : '${endDate.year}/'}${endDate.month}/${endDate.day}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _selectDateRange,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Card(
                margin: const EdgeInsets.all(16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildHabitCard(widget.habit),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabitCard(Habit habit) {
    final completionRate = habit.type == HabitType.boolean
        ? habit.getCompletionRate(startDate, endDate)
        : 0.0;
    final stats = _calculateStats(habit, startDate, endDate);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (habit.type == HabitType.boolean)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.2),
                  ),
                  padding: const EdgeInsets.all(2),
                  width: 35,
                  height: 35,
                  child: CircularProgressIndicator(
                    value: completionRate,
                    backgroundColor: Colors.grey[200],
                    strokeWidth: 3.5,
                    color: _getCompletionColor(completionRate),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.2),
                  ),
                  padding: const EdgeInsets.all(8),
                  width: 35,
                  height: 35,
                  child: Icon(
                    Icons.straighten,
                    size: 18,
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
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      habit.type == HabitType.boolean ? '完成与否' : '可量化的习惯',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (habit.type == HabitType.boolean)
                      Row(
                        children: [
                          const Text(
                            '完成率: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getCompletionColor(completionRate)
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${(completionRate * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _getCompletionColor(completionRate),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 统计数据卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${habit.name}统计',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (habit.type == HabitType.boolean) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getCompletionColor(completionRate)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: _getCompletionColor(completionRate),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '完成率 ${(completionRate * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getCompletionColor(completionRate),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (habit.type == HabitType.boolean)
                      _buildStatItem(
                        '完成次数',
                        '${stats.totalCount}次',
                        Icons.check_circle_outline,
                      ),
                    if (habit.type == HabitType.quantifiable)
                      _buildStatItem(
                        '累计${habit.unit}',
                        stats.totalValue.toString(),
                        Icons.summarize,
                      ),
                    _buildStatItem(
                      '平均每${currentView == ViewType.daily ? "天" : currentView == ViewType.weekly ? "周" : "月"}',
                      habit.type == HabitType.boolean
                          ? '${stats.averageCount}%'
                          : '${stats.averageValue}${habit.unit}',
                      Icons.trending_up,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    currentView == ViewType.daily
                        ? Icons.calendar_today
                        : currentView == ViewType.weekly
                            ? Icons.calendar_view_week
                            : Icons.calendar_view_month,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentView == ViewType.daily
                        ? '每日数据'
                        : currentView == ViewType.weekly
                            ? '每周数据'
                            : '每月数据',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    currentChartType == ChartType.bar
                        ? Icons.bar_chart
                        : currentChartType == ChartType.line
                            ? Icons.show_chart
                            : Icons.pie_chart,
                    size: 16,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    currentChartType == ChartType.bar
                        ? '柱状图'
                        : currentChartType == ChartType.line
                            ? '折线图'
                            : '饼图',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildChart(widget.habit),
          ),
          if (currentView == ViewType.daily) ...[
            const SizedBox(height: 16),
            _buildDailyView(),
          ],
        ],
      ),
    );
  }

  // 根据完成率获取颜色
  Color _getCompletionColor(double rate) {
    if (rate <= 0.2) return Colors.red;
    if (rate <= 0.5) return Colors.orange;
    if (rate <= 0.8) return Colors.amber;
    return Colors.green;
  }

  // 添加统计项小部件
  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // 计算统计数据
  Stats _calculateStats(Habit habit, DateTime startDate, DateTime endDate) {
    int totalCount = 0;
    double totalValue = 0;

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (habit.history.containsKey(key)) {
        // 布尔型习惯只有完成才计入次数
        if (habit.type == HabitType.boolean) {
          if (habit.history[key] == true) {
            totalCount++;
            totalValue++;
          }
        } else {
          // 可量化习惯不计总次数，只计总值
          totalValue += habit.history[key] as double;
          totalCount++; // 记录有数据的天数，用于后续计算
        }
      }
    }

    final days = endDate.difference(startDate).inDays + 1;

    return Stats(
      totalCount: totalCount,
      totalValue: totalValue.toInt(), // 保持原始值
      averageCount: habit.type == HabitType.boolean
          ? ((totalCount / days) * 100).toInt()
          : 0, // 保持原始值,只用于布尔型
      averageValue: habit.type == HabitType.boolean
          ? (totalCount > 0 ? (totalValue / totalCount).toInt() : 0)
          : // 布尔型：平均每次记录的值
          (days > 0 ? (totalValue / days).toInt() : 0), // 可量化型：平均每天的值
    );
  }

  // 获取图表数据
  List<ChartData> _getChartData(Habit habit) {
    switch (currentView) {
      case ViewType.daily:
        return _getDailyData(habit);
      case ViewType.weekly:
        return _getWeeklyData(habit);
      case ViewType.monthly:
        return _getMonthlyData(habit);
    }
  }

  List<ChartData> _getDailyData(Habit habit) {
    final data = <ChartData>[];
    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      final key = DateTime(date.year, date.month, date.day);
      if (habit.history.containsKey(key)) {
        final value = habit.type == HabitType.boolean
            ? (habit.history[key] == true ? 1.0 : 0.0)
            : (habit.history[key] as double);
        data.add(ChartData(date, value));
      } else {
        data.add(ChartData(date, 0));
      }
    }
    return data;
  }

  List<ChartData> _getWeeklyData(Habit habit) {
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
      if (values.isEmpty) return ChartData(entry.key, 0);

      if (habit.type == HabitType.boolean) {
        // 布尔型习惯：计算完成次数
        final completedDays = values.where((v) => v > 0).length;
        return ChartData(entry.key, completedDays.toDouble());
      } else {
        // 可量化习惯：计算总和
        final sum = values.reduce((a, b) => a + b);
        return ChartData(entry.key, sum);
      }
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<ChartData> _getMonthlyData(Habit habit) {
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
      if (values.isEmpty) return ChartData(entry.key, 0);

      if (habit.type == HabitType.boolean) {
        // 布尔型习惯：计算完成次数
        final completedDays = values.where((v) => v > 0).length;
        return ChartData(entry.key, completedDays.toDouble());
      } else {
        // 可量化习惯：计算总和
        final sum = values.reduce((a, b) => a + b);
        return ChartData(entry.key, sum);
      }
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
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

  Widget _buildBarChart(List<ChartData> data, Habit habit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      child: data.isEmpty
          ? Center(
              child: Text(
                '暂无数据',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final item = data[index];
                      final maxValue = data.fold<double>(
                        0,
                        (max, item) => item.value > max ? item.value : max,
                      );
                      final heightRatio =
                          maxValue == 0 ? 0 : (item.value / maxValue);
                      // 限制最大高度为70，确保有足够空间放置标签
                      final barHeight = max(2.0, min(70.0, heightRatio * 70.0));

                      String valueText;
                      if (habit.type == HabitType.boolean) {
                        valueText = currentView == ViewType.daily
                            ? (item.value > 0 ? '完成' : '未完成')
                            : '${item.value.toStringAsFixed(0)}次';
                      } else {
                        valueText =
                            '${item.value.toStringAsFixed(1)}${habit.unit}';
                      }

                      final color =
                          _getBarColor(item.value, maxValue, habit.type);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width:
                                  currentView == ViewType.daily ? 40.0 : 55.0,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                valueText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    width: currentView == ViewType.daily
                                        ? 25.0
                                        : 40.0,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          color.withOpacity(0.5),
                                          color,
                                        ],
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color.withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: currentView == ViewType.daily
                                        ? 25.0
                                        : 40.0,
                                    height: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              width:
                                  currentView == ViewType.daily ? 40.0 : 55.0,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 6),
                              margin: const EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                currentView == ViewType.daily
                                    ? '${item.date.day}日'
                                    : currentView == ViewType.weekly
                                        ? '${_getWeekNumber(item.date)}周'
                                        : '${item.date.month}月',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 添加底部空间解决溢出问题
                const SizedBox(height: 5),
              ],
            ),
    );
  }

  // 根据数值获取柱形图的颜色
  Color _getBarColor(double value, double maxValue, HabitType type) {
    if (value <= 0) return Colors.grey.shade300;

    if (type == HabitType.boolean) {
      return Theme.of(context).colorScheme.primary;
    } else {
      final ratio = value / maxValue;
      if (ratio < 0.3) {
        return Colors.blue.shade300;
      } else if (ratio < 0.6) {
        return Colors.blue.shade500;
      } else if (ratio < 0.9) {
        return Colors.blue.shade700;
      } else {
        return Colors.blue.shade900;
      }
    }
  }

  Widget _buildLineChart(List<ChartData> data, Habit habit) {
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

  Widget _buildPieChart(List<ChartData> data, Habit habit) {
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
              title:
                  '${values.first.toStringAsFixed(1)}${habit.unit}\n${values.length}次',
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
    final key = DateTime(date.year, date.month, date.day);

    if (habit.type == HabitType.boolean) {
      valueController.text = habit.history[key] == true ? '1' : '0';
    } else {
      valueController.text = (habit.history[key] ?? '').toString();
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
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
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
                      isSelected: habit.history[key] == false,
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
                      isSelected: habit.history[key] == true,
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
                          const TextInputType.numberWithOptions(decimal: true),
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
          if (habit.history.containsKey(key))
            TextButton.icon(
              onPressed: () {
                setState(() {
                  habit.history.remove(key);
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

  // 导出功能
  Future<void> _exportHabitData(Habit habit) async {
    try {
      // 创建 CSV 内容
      final csvRows = habit.toCsvRows();
      final csvContent = csvRows.join('\n');

      // 获取应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      final shortName = habit.name.length > 20
          ? '${habit.name.substring(0, 20)}...'
          : habit.name;
      final fileName =
          '${shortName}_记录_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      // 写入文件
      await file.writeAsString(csvContent, flush: true);

      // 分享文件
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: '习惯记录数据',
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
