import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import '../utils/custom_logic.dart';
import '../widgets/common_app_bar.dart';
import 'qr_import_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CustomLogicScreen extends StatefulWidget {
  const CustomLogicScreen({Key? key}) : super(key: key);

  @override
  State<CustomLogicScreen> createState() => _CustomLogicScreenState();
}

class _CustomLogicScreenState extends State<CustomLogicScreen> with SingleTickerProviderStateMixin {
  final AppSettings _settings = AppSettings.instance;
  final TextEditingController _editorController = TextEditingController();
  late TabController _tabController;
  List<CustomLogicRule> _rules = [];
  String? _editorError;
  String? _sampleData;
  String? _samplePretty;
  String? _fileStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFromSettings();
  }

  void _loadFromSettings() {
    _rules = CustomLogicEngine.parseRules(_settings.customLogicJson);
    _editorController.text = _settings.customLogicJson;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final json = CustomLogicEngine.rulesToJson(_rules);
    await _settings.setCustomLogicJson(json);
    setState(() {
      _editorController.text = json;
      _editorError = null;
    });
  }

  Future<void> _saveEditorJson() async {
    try {
      final raw = _editorController.text.trim();
      if (raw.isEmpty) {
        setState(() {
          _editorError = 'Editor is empty';
        });
        return;
      }

      final decoded = json.decode(raw);
      final isQrRules = decoded is Map<String, dynamic> &&
          decoded.containsKey('rules') &&
          decoded.containsKey('data') &&
          decoded.containsKey('token');

      if (isQrRules) {
        await _settings.setCustomLogicJson(raw);
        _rules = [];
      } else {
        final parsed = CustomLogicEngine.parseRules(raw);
        _rules = parsed;
        await _settings.setCustomLogicJson(raw);
      }
      setState(() {
        _editorError = null;
      });
    } catch (e) {
      setState(() {
        _editorError = 'Invalid JSON format';
      });
    }
  }

  Future<void> _importFromQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrImportScreen()),
    );
    if (result == null || result.trim().isEmpty) return;

    final json = CustomLogicEngine.tryParseJson(result);
    setState(() {
      _sampleData = result;
      _samplePretty = json != null ? const JsonEncoder.withIndent('  ').convert(json) : null;
    });

    if (json is Map<String, dynamic>) {
      _editorController.text = result;
      await _saveEditorJson();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR data is not JSON. Sample saved for reference.')),
        );
      }
    }
  }

  Future<File> _getCustomLogicFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/custom_logic.json');
  }

  Future<void> _exportToFile() async {
    final file = await _getCustomLogicFile();
    await file.writeAsString(_editorController.text);
    setState(() {
      _fileStatus = 'Exported to ${file.path}';
    });
  }

  Future<void> _importFromFile() async {
    final file = await _getCustomLogicFile();
    if (!await file.exists()) {
      setState(() {
        _fileStatus = 'No export file found yet.';
      });
      return;
    }
    final content = await file.readAsString();
    _editorController.text = content;
    await _saveEditorJson();
    setState(() {
      _fileStatus = 'Imported from ${file.path}';
    });
  }

  Future<void> _openRuleEditor({CustomLogicRule? rule, int? index}) async {
    final nameController = TextEditingController(text: rule?.name ?? '');
    String conditionType = rule?.condition.type ?? 'contains';
    final conditionValueController = TextEditingController(text: rule?.condition.value ?? '');
    final conditionFieldController = TextEditingController(text: rule?.condition.field ?? '');

    String actionType = rule?.actions.isNotEmpty == true ? rule!.actions.first.type : 'show_message';
    final actionValueController = TextEditingController(text: rule?.actions.isNotEmpty == true ? rule!.actions.first.value ?? '' : '');
    final actionFieldsController = TextEditingController(
      text: rule?.actions.isNotEmpty == true ? (rule!.actions.first.fields ?? []).join(', ') : '',
    );
    final actionMappingController = TextEditingController(
      text: rule?.actions.isNotEmpty == true
          ? (rule!.actions.first.mapping ?? {}).entries.map((e) => '${e.key}=${e.value}').join('\n')
          : '',
    );
    bool saveToHistory = rule?.saveToHistory ?? false;
    bool actionSound = rule?.actions.any((a) => a.type == 'sound') ?? false;
    bool actionVibrate = rule?.actions.any((a) => a.type == 'vibrate') ?? false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      rule == null ? 'Add Rule' : 'Edit Rule',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Rule Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: conditionType,
                      decoration: const InputDecoration(labelText: 'Condition Type'),
                      items: const [
                        DropdownMenuItem(value: 'exact', child: Text('Exact Match')),
                        DropdownMenuItem(value: 'contains', child: Text('Contains Keyword')),
                        DropdownMenuItem(value: 'json_field_equals', child: Text('JSON Field Equals')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          conditionType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (conditionType == 'json_field_equals')
                      TextField(
                        controller: conditionFieldController,
                        decoration: const InputDecoration(labelText: 'JSON Field Path (e.g. data.type)'),
                      ),
                    if (conditionType == 'json_field_equals') const SizedBox(height: 12),
                    TextField(
                      controller: conditionValueController,
                      decoration: const InputDecoration(labelText: 'Condition Value'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: actionType,
                      decoration: const InputDecoration(labelText: 'Primary Action'),
                      items: const [
                        DropdownMenuItem(value: 'open_url', child: Text('Open URL')),
                        DropdownMenuItem(value: 'show_message', child: Text('Show Message')),
                        DropdownMenuItem(value: 'show_json_fields', child: Text('Show JSON Fields')),
                        DropdownMenuItem(value: 'show_result', child: Text('Show Result (Mapped JSON)')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() {
                          actionType = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    if (actionType == 'show_json_fields')
                      TextField(
                        controller: actionFieldsController,
                        decoration: const InputDecoration(labelText: 'Fields (comma separated)'),
                      )
                    else if (actionType == 'show_result')
                      TextField(
                        controller: actionMappingController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Output Mapping (Label=path per line)',
                          hintText: 'Name=data.name\nAmount=data.total',
                        ),
                      )
                    else
                      TextField(
                        controller: actionValueController,
                        decoration: const InputDecoration(labelText: 'Action Value (use {raw} or field:path)'),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: saveToHistory,
                      title: const Text('Save to History'),
                      onChanged: (value) {
                        setSheetState(() {
                          saveToHistory = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: actionSound,
                      title: const Text('Play Sound'),
                      onChanged: (value) {
                        setSheetState(() {
                          actionSound = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      value: actionVibrate,
                      title: const Text('Vibrate'),
                      onChanged: (value) {
                        setSheetState(() {
                          actionVibrate = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim().isEmpty ? 'Rule' : nameController.text.trim();
                        final condition = CustomLogicCondition(
                          type: conditionType,
                          value: conditionValueController.text.trim(),
                          field: conditionFieldController.text.trim(),
                        );

                        final actions = <CustomLogicAction>[];
                        if (actionType == 'show_json_fields') {
                          actions.add(
                            CustomLogicAction(
                              type: actionType,
                              fields: actionFieldsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                            ),
                          );
                        } else if (actionType == 'show_result') {
                          final mapping = <String, String>{};
                          for (final line in actionMappingController.text.split('\n')) {
                            final trimmed = line.trim();
                            if (trimmed.isEmpty || !trimmed.contains('=')) continue;
                            final parts = trimmed.split('=');
                            final label = parts.first.trim();
                            final path = parts.sublist(1).join('=').trim();
                            if (label.isNotEmpty && path.isNotEmpty) {
                              mapping[label] = path;
                            }
                          }
                          actions.add(
                            CustomLogicAction(
                              type: actionType,
                              mapping: mapping,
                            ),
                          );
                        } else {
                          actions.add(
                            CustomLogicAction(
                              type: actionType,
                              value: actionValueController.text.trim(),
                            ),
                          );
                        }
                        if (actionSound) {
                          actions.add(CustomLogicAction(type: 'sound'));
                        }
                        if (actionVibrate) {
                          actions.add(CustomLogicAction(type: 'vibrate'));
                        }

                        final newRule = CustomLogicRule(
                          name: name,
                          condition: condition,
                          actions: actions,
                          saveToHistory: saveToHistory,
                        );

                        setState(() {
                          if (index != null) {
                            _rules[index] = newRule;
                          } else {
                            _rules.add(newRule);
                          }
                        });
                        _saveRules();
                        Navigator.pop(context);
                      },
                      child: const Text('Save Rule'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteRule(int index) async {
    setState(() {
      _rules.removeAt(index);
    });
    await _saveRules();
  }

  void _openRuleInEditor(CustomLogicRule rule) {
    final json = CustomLogicEngine.rulesToJson([rule]);
    setState(() {
      _editorController.text = json;
      _editorError = null;
    });
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: Column(
        children: [
          SwitchListTile(
            value: _settings.customLogicEnabled,
            title: const Text('Enable Custom Logic'),
            subtitle: const Text('Run your custom rules before default scan behavior'),
            onChanged: (value) => _settings.setCustomLogicEnabled(value),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Rules'),
              Tab(text: 'Editor'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesTab(),
                _buildEditorTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () => _openRuleEditor(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildRulesTab() {
    final ruleTiles = _rules
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final rule = entry.value;
          final actionSummary = rule.actions.map((a) => a.type.replaceAll('_', ' ')).join(', ');
          return Card(
            child: ListTile(
              title: Text(rule.name),
              subtitle: Text('${rule.condition.type} • ${rule.condition.value ?? ''}\nActions: $actionSummary'),
              isThreeLine: true,
              onTap: () => _openRuleEditor(rule: rule, index: index),
              onLongPress: () => _openRuleInEditor(rule),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openRuleEditor(rule: rule, index: index);
                  } else if (value == 'delete') {
                    _deleteRule(index);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
          );
        })
        .toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFromQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR to Import'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportToFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Export'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _importFromFile,
          icon: const Icon(Icons.download),
          label: const Text('Import'),
        ),
        if (_fileStatus != null) const SizedBox(height: 6),
        if (_fileStatus != null)
          Text(
            _fileStatus!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 12),
        if (_rules.isEmpty)
          const Center(child: Text('No rules yet. Tap + to add a rule.'))
        else
          ...ruleTiles,
      ],
    );
  }

  Widget _buildEditorTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 240,
          child: TextField(
            controller: _editorController,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              labelText: 'Custom Logic JSON',
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
              errorText: _editorError,
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saveEditorJson,
                child: const Text('Validate & Save'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _saveRules,
                child: const Text('Sync From Rules'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exportToFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('Export'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFromFile,
                icon: const Icon(Icons.download),
                label: const Text('Import'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importFromQr,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR to Import'),
              ),
            ),
          ],
        ),
        if (_fileStatus != null) const SizedBox(height: 8),
        if (_fileStatus != null)
          Text(
            _fileStatus!,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        if (_sampleData != null) const SizedBox(height: 12),
        if (_sampleData != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sample QR Data', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _samplePretty ?? _sampleData!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
