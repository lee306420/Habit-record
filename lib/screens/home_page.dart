import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import '../models/habit.dart';
import '../utils/enums.dart';
import 'habit_history_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Habit> habits = [];
  final String _storageKey = 'habits';
  String? _customStoragePath;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadCustomStoragePath().then((_) => _loadHabits());
  }

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
    }
  }

  Future<void> _addHabit() async {
    final nameController = TextEditingController();
    HabitType selectedType = HabitType.boolean;
    final unitController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                Icons.add_task,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text('添加新习惯'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '习惯名称',
                    hintText: '例如：早起、跑步等',
                    filled: true,
                    fillColor: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.edit),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceVariant
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '习惯类型',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      RadioListTile<HabitType>(
                        title: const Text('完成与否'),
                        subtitle: const Text('记录简单的完成情况'),
                        value: HabitType.boolean,
                        groupValue: selectedType,
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedType = value!;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      RadioListTile<HabitType>(
                        title: const Text('可量化的'),
                        subtitle: const Text('记录具体的数值'),
                        value: HabitType.quantifiable,
                        groupValue: selectedType,
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedType = value!;
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selectedType == HabitType.quantifiable)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: unitController,
                      decoration: InputDecoration(
                        labelText: '单位',
                        hintText: '例如：次、分钟、公里',
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.straighten),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton.icon(
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
              icon: const Icon(Icons.add),
              label: const Text('添加'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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

  void _showHabitHistory(Habit habit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HabitHistoryPage(
          habit: habit,
          onHabitUpdated: _saveHabits,
        ),
      ),
    ).then((_) {
      // 从详情页返回时刷新数据
      setState(() {
        // 刷新界面状态
      });
      // 重新从存储加载数据以确保同步
      _loadHabits();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '习惯打卡',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsMenu(context);
            },
            tooltip: '设置',
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
        child: habits.isEmpty
            ? _buildEmptyState(context)
            : AnimatedList(
                initialItemCount: habits.length,
                key: GlobalKey<AnimatedListState>(),
                itemBuilder: (context, index, animation) {
                  final habit = habits[index];
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: _buildHabitItem(habit),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHabit,
        tooltip: '添加新习惯',
        child: const Icon(Icons.add),
        elevation: 4,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '还没有习惯',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮开始添加你的第一个习惯吧！',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _addHabit,
            icon: const Icon(Icons.add),
            label: const Text('添加第一个习惯'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitItem(Habit habit) {
    final theme = Theme.of(context);

    // 确保显示正确的完成状态
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final isCompleted = habit.type == HabitType.boolean
        ? habit.completed
        : habit.history.containsKey(today) &&
            (habit.history[today] as double) > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isCompleted
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.cardTheme.color,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showHabitHistory(habit),
        onLongPress: () => _showEditMenu(habit),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListTile(
            title: Text(
              habit.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                habit.type == HabitType.boolean
                    ? (habit.completed ? '今日已完成' : '今日未完成')
                    : '今日进度：${habit.history.containsKey(today) ? (habit.history[today] as double).toStringAsFixed(1) : '0.0'}${habit.unit}',
                style: TextStyle(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: isCompleted
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.withOpacity(0.6),
              radius: 24,
              child: Text(
                habit.name.isNotEmpty ? habit.name[0] : '?',
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              onPressed: () => _showHabitHistory(habit),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditMenu(Habit habit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '管理习惯: ${habit.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text('修改名称'),
              onTap: () {
                Navigator.pop(context);
                _showEditHabitNameDialog(habit);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
              ),
              title: const Text('删除习惯', style: TextStyle(color: Colors.red)),
              subtitle:
                  const Text('此操作不可恢复', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteHabit(habit);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteHabit(Habit habit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要删除习惯',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '"${habit.name}"',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            const Text(
              '所有记录都将被删除，此操作不可恢复。',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        habits.remove(habit);
      });
      _saveHabits();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('习惯已删除')),
        );
      }
    }
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '设置',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.upload_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: const Text('导出所有数据'),
              subtitle: const Text('将习惯数据保存到文件'),
              onTap: () {
                Navigator.pop(context);
                _exportAllData();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.download_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              title: const Text('导入数据'),
              subtitle: const Text('从文件恢复习惯数据'),
              onTap: () {
                Navigator.pop(context);
                _importData();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
              title: const Text('设置存储路径'),
              subtitle: FutureBuilder<String>(
                future: _getStoragePath(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  return Text(
                    _getDisplayPath(snapshot.data!),
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  );
                },
              ),
              onTap: () {
                Navigator.pop(context);
                _showSetStoragePathDialog();
              },
            ),
          ],
        ),
      ),
    );
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
        await Share.shareFiles(
          [file.path],
          text: '习惯记录数据备份',
        ).then((_) {
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
}
