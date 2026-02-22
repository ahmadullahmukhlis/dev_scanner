import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import '../widgets/common_app_bar.dart';
import 'qr_import_screen.dart';

class GatewayRulesScreen extends StatefulWidget {
  const GatewayRulesScreen({Key? key}) : super(key: key);

  @override
  State<GatewayRulesScreen> createState() => _GatewayRulesScreenState();
}

class _GatewayRulesScreenState extends State<GatewayRulesScreen> with SingleTickerProviderStateMixin {
  final AppSettings _settings = AppSettings.instance;
  final TextEditingController _editorController = TextEditingController();
  late TabController _tabController;
  String? _error;
  List<Map<String, dynamic>> _rules = [];
  int? _selectedRuleIndex;
  Timer? _jsonSyncTimer;
  bool _isUpdatingFromBuilder = false;
  String _builderName = 'New Rule';
  String _builderConditionMode = 'all';
  List<_ConditionRow> _builderConditions = [];
  bool _builderRedirectEnabled = true;
  String _builderRedirectUrl = '';
  List<_KeyValueRow> _builderRedirectParams = [];
  bool _builderApiEnabled = false;
  String _builderApiUrl = '';
  List<_KeyValueRow> _builderApiBody = [];
  bool _builderMessageEnabled = false;
  String _builderMessage = '';
  bool _builderSaveHistory = false;
  List<_KeyValueRow> _builderFieldMap = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _editorController.addListener(_onJsonEditorChanged);
    _loadRulesFromSettings();
  }

  @override
  void dispose() {
    _jsonSyncTimer?.cancel();
    _editorController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadRulesFromSettings() {
    _rules = [];
    _selectedRuleIndex = null;
    final raw = _settings.gatewayRulesJson.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic> && decoded['rules'] is List) {
        _rules = (decoded['rules'] as List).whereType<Map<String, dynamic>>().toList();
        if (_rules.isNotEmpty) {
          _selectedRuleIndex = 0;
          _editorController.text = const JsonEncoder.withIndent('  ').convert(_rules.first);
          _loadBuilderFromRule(_rules.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveAllRules() async {
    final payload = {'rules': _rules};
    final raw = const JsonEncoder.withIndent('  ').convert(payload);
    await _settings.setGatewayRulesJson(raw);
  }

  Future<void> _saveCurrentRule() async {
    final raw = _editorController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Editor is empty');
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _error = 'Rule must be a JSON object');
        return;
      }
      setState(() {
        if (_selectedRuleIndex == null) {
          _rules.add(decoded);
          _selectedRuleIndex = _rules.length - 1;
        } else {
          _rules[_selectedRuleIndex!] = decoded;
        }
        _error = null;
      });
      _loadBuilderFromRule(decoded);
      await _saveAllRules();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rule saved')),
        );
      }
    } catch (_) {
      setState(() => _error = 'Invalid JSON');
    }
  }

  Future<void> _scanSampleAndGenerate() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrImportScreen()),
    );
    if (result == null || result.trim().isEmpty) return;

    Map<String, dynamic>? data;
    try {
      final decoded = json.decode(result);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      data = null;
    }

    if (data == null || data.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR does not contain JSON object')),
        );
      }
      return;
    }

    final urlController = TextEditingController(text: 'https://your-domain.com');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gateway URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(labelText: 'Redirect URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Use')),
        ],
      ),
    );
    if (confirmed != true) return;

    final params = <String, dynamic>{};
    data.forEach((key, value) {
      params[key] = '\$$key';
    });

    final newRule = {
      'name': 'Auto Rule',
      'condition': {
        'field': data.keys.first,
        'operator': 'exists',
        'value': true,
      },
      'actions': [
        {
          'type': 'redirect',
          'url': urlController.text.trim(),
          'params': params,
        },
      ],
    };

    setState(() {
      _rules.add(newRule);
      _selectedRuleIndex = _rules.length - 1;
      _editorController.text = const JsonEncoder.withIndent('  ').convert(newRule);
      _error = null;
    });
    _loadBuilderFromRule(newRule);
    await _saveAllRules();
    _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Custom Gateway Rules Editor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            value: _settings.gatewayRulesEnabled,
            title: const Text('Enable Custom Rules'),
            subtitle: const Text('Apply rules to JSON QR scans'),
            onChanged: (value) => _settings.setGatewayRulesEnabled(value),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Rules'),
              Tab(text: 'Editor'),
              Tab(text: 'Examples'),
              Tab(text: 'Variables'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRulesTab(),
                _buildEditorTab(),
                _buildExamplesTab(),
                _buildVariablesTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _addEmptyRule,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

extension on _GatewayRulesScreenState {
  void _loadBuilderFromRule(Map<String, dynamic> rule) {
    _builderName = rule['name']?.toString() ?? 'Rule';
    _builderConditions = [];
    _builderConditionMode = 'all';
    final condition = rule['condition'];
    if (condition is Map<String, dynamic>) {
      if (condition['all'] is List) {
        _builderConditionMode = 'all';
        for (final item in (condition['all'] as List)) {
          if (item is Map<String, dynamic>) {
            _builderConditions.add(
              _ConditionRow(
                field: item['field']?.toString() ?? '',
                operatorType: item['operator']?.toString() ?? 'equals',
                value: item['value']?.toString() ?? '',
              ),
            );
          }
        }
      } else if (condition['any'] is List) {
        _builderConditionMode = 'any';
        for (final item in (condition['any'] as List)) {
          if (item is Map<String, dynamic>) {
            _builderConditions.add(
              _ConditionRow(
                field: item['field']?.toString() ?? '',
                operatorType: item['operator']?.toString() ?? 'equals',
                value: item['value']?.toString() ?? '',
              ),
            );
          }
        }
      } else {
        _builderConditions.add(
          _ConditionRow(
            field: condition['field']?.toString() ?? '',
            operatorType: condition['operator']?.toString() ?? 'equals',
            value: condition['value']?.toString() ?? '',
          ),
        );
      }
    }
    if (_builderConditions.isEmpty) {
      _builderConditions.add(_ConditionRow(field: '', operatorType: 'equals', value: ''));
    }

    _builderRedirectEnabled = false;
    _builderRedirectUrl = '';
    _builderRedirectParams = [];
    _builderApiEnabled = false;
    _builderApiUrl = '';
    _builderApiBody = [];
    _builderMessageEnabled = false;
    _builderMessage = '';
    _builderSaveHistory = false;

    if (rule['actions'] is List) {
      for (final action in (rule['actions'] as List)) {
        if (action is! Map<String, dynamic>) continue;
        final type = action['type']?.toString();
        if (type == 'redirect') {
          _builderRedirectEnabled = true;
          _builderRedirectUrl = action['url']?.toString() ?? '';
          _builderRedirectParams = _mapToPairs(action['params']);
        } else if (type == 'api_call' || type == 'backend_hook') {
          _builderApiEnabled = true;
          _builderApiUrl = action['url']?.toString() ?? '';
          _builderApiBody = _mapToPairs(action['body']);
        } else if (type == 'show_message') {
          _builderMessageEnabled = true;
          _builderMessage = action['message']?.toString() ?? '';
        } else if (type == 'save_history') {
          _builderSaveHistory = true;
        }
      }
    }

    _builderFieldMap = [];
    final replace = rule['replace'];
    if (replace is Map<String, dynamic> && replace['field_map'] is Map) {
      _builderFieldMap = _mapToPairs(replace['field_map']);
    }
  }

  List<_KeyValueRow> _mapToPairs(dynamic raw) {
    if (raw is Map) {
      return raw.entries
          .map((e) => _KeyValueRow(keyText: e.key.toString(), valueText: e.value.toString()))
          .toList();
    }
    return [];
  }

  Future<void> _applyBuilderToRule() async {
    final conditions = _builderConditions
        .where((c) => c.field.trim().isNotEmpty)
        .map((c) => {
              'field': c.field.trim(),
              'operator': c.operatorType,
              'value': c.value.trim(),
            })
        .toList();

    final condition = conditions.length <= 1
        ? (conditions.isEmpty ? {'field': '', 'operator': 'equals', 'value': ''} : conditions.first)
        : {
            _builderConditionMode: conditions,
          };

    final actions = <Map<String, dynamic>>[];
    if (_builderRedirectEnabled) {
      actions.add({
        'type': 'redirect',
        'url': _builderRedirectUrl.trim(),
        'params': _pairsToMap(_builderRedirectParams),
      });
    }
    if (_builderApiEnabled) {
      actions.add({
        'type': 'api_call',
        'url': _builderApiUrl.trim(),
        'body': _pairsToMap(_builderApiBody),
      });
    }
    if (_builderMessageEnabled) {
      actions.add({
        'type': 'show_message',
        'message': _builderMessage.trim(),
      });
    }
    if (_builderSaveHistory) {
      actions.add({'type': 'save_history'});
    }

    final replace = _builderFieldMap.isEmpty
        ? null
        : {
            'field_map': _pairsToMap(_builderFieldMap),
          };

    final rule = <String, dynamic>{
      'name': _builderName.trim().isEmpty ? 'Rule' : _builderName.trim(),
      'condition': condition,
      'actions': actions,
    };
    if (replace != null) {
      rule['replace'] = replace;
    }

    setState(() {
      if (_selectedRuleIndex == null) {
        _rules.add(rule);
        _selectedRuleIndex = _rules.length - 1;
      } else {
        _rules[_selectedRuleIndex!] = rule;
      }
      _isUpdatingFromBuilder = true;
      _editorController.text = const JsonEncoder.withIndent('  ').convert(rule);
      _isUpdatingFromBuilder = false;
      _error = null;
    });
    await _saveAllRules();
  }

  Map<String, dynamic> _pairsToMap(List<_KeyValueRow> rows) {
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row.keyText.trim();
      if (key.isEmpty) continue;
      map[key] = row.valueText.trim();
    }
    return map;
  }

  void _showJsonDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rule JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _editorController.text.trim(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _applyJsonToBuilder() {
    final raw = _editorController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'JSON is empty');
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) {
        setState(() => _error = 'Rule JSON must be an object');
        return;
      }
      _loadBuilderFromRule(decoded);
      setState(() {
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Invalid JSON');
    }
  }

  void _onJsonEditorChanged() {
    if (_isUpdatingFromBuilder) return;
    if (_selectedRuleIndex == null) return;
    _jsonSyncTimer?.cancel();
    _jsonSyncTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final raw = _editorController.text.trim();
      if (raw.isEmpty) {
        setState(() => _error = 'JSON is empty');
        return;
      }
      try {
        final decoded = json.decode(raw);
        if (decoded is! Map<String, dynamic>) {
          setState(() => _error = 'Rule JSON must be an object');
          return;
        }
        _loadBuilderFromRule(decoded);
        if (mounted) {
          setState(() => _error = null);
        }
      } catch (_) {
        setState(() => _error = 'Invalid JSON');
      }
    });
  }

  void _formatJson() {
    final raw = _editorController.text.trim();
    if (raw.isEmpty) return;
    try {
      final decoded = json.decode(raw);
      _editorController.text = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() => _error = null);
    } catch (_) {
      setState(() => _error = 'Invalid JSON');
    }
  }

  Widget _buildBuilderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: _builderName,
          decoration: const InputDecoration(labelText: 'Rule Name'),
          onChanged: (value) => _builderName = value,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Condition Mode:'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _builderConditionMode,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ALL (AND)')),
                DropdownMenuItem(value: 'any', child: Text('ANY (OR)')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _builderConditionMode = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._builderConditions.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 140,
                child: TextFormField(
                  initialValue: row.field,
                  decoration: const InputDecoration(labelText: 'Field'),
                  onChanged: (value) => row.field = value,
                ),
              ),
              SizedBox(
                width: 140,
                child: DropdownButtonFormField<String>(
                  value: row.operatorType,
                  decoration: const InputDecoration(labelText: 'Op'),
                  items: const [
                    DropdownMenuItem(value: 'equals', child: Text('equals')),
                    DropdownMenuItem(value: 'contains', child: Text('contains')),
                    DropdownMenuItem(value: 'exists', child: Text('exists')),
                    DropdownMenuItem(value: 'gt', child: Text('gt')),
                    DropdownMenuItem(value: 'lt', child: Text('lt')),
                    DropdownMenuItem(value: 'gte', child: Text('gte')),
                    DropdownMenuItem(value: 'lte', child: Text('lte')),
                    DropdownMenuItem(value: 'starts_with', child: Text('starts_with')),
                    DropdownMenuItem(value: 'ends_with', child: Text('ends_with')),
                    DropdownMenuItem(value: 'in', child: Text('in')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    row.operatorType = value;
                  },
                ),
              ),
              SizedBox(
                width: 160,
                child: TextFormField(
                  initialValue: row.value,
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (value) => row.value = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _builderConditions.removeAt(index);
                    if (_builderConditions.isEmpty) {
                      _builderConditions.add(_ConditionRow(field: '', operatorType: 'equals', value: ''));
                    }
                  });
                },
              ),
            ],
          );
        }),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _builderConditions.add(_ConditionRow(field: '', operatorType: 'equals', value: ''));
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Condition'),
        ),
        const SizedBox(height: 12),
        _buildKeyValueSection(
          title: 'Field Mapping (Rename/Swap)',
          rows: _builderFieldMap,
          onAdd: () => setState(() => _builderFieldMap.add(_KeyValueRow())),
          onRemove: (index) => setState(() => _builderFieldMap.removeAt(index)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _builderRedirectEnabled,
          title: const Text('Redirect'),
          onChanged: (value) => setState(() => _builderRedirectEnabled = value),
        ),
        if (_builderRedirectEnabled)
          TextFormField(
            initialValue: _builderRedirectUrl,
            decoration: const InputDecoration(labelText: 'Redirect URL'),
            onChanged: (value) => _builderRedirectUrl = value,
          ),
        if (_builderRedirectEnabled)
          _buildKeyValueSection(
            title: 'Redirect Params',
            rows: _builderRedirectParams,
            onAdd: () => setState(() => _builderRedirectParams.add(_KeyValueRow())),
            onRemove: (index) => setState(() => _builderRedirectParams.removeAt(index)),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _builderApiEnabled,
          title: const Text('API Call / Backend Hook'),
          onChanged: (value) => setState(() => _builderApiEnabled = value),
        ),
        if (_builderApiEnabled)
          TextFormField(
            initialValue: _builderApiUrl,
            decoration: const InputDecoration(labelText: 'API URL'),
            onChanged: (value) => _builderApiUrl = value,
          ),
        if (_builderApiEnabled)
          _buildKeyValueSection(
            title: 'API Body',
            rows: _builderApiBody,
            onAdd: () => setState(() => _builderApiBody.add(_KeyValueRow())),
            onRemove: (index) => setState(() => _builderApiBody.removeAt(index)),
          ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: _builderMessageEnabled,
          title: const Text('Show Message'),
          onChanged: (value) => setState(() => _builderMessageEnabled = value),
        ),
        if (_builderMessageEnabled)
          TextFormField(
            initialValue: _builderMessage,
            decoration: const InputDecoration(labelText: 'Message'),
            onChanged: (value) => _builderMessage = value,
          ),
        SwitchListTile(
          value: _builderSaveHistory,
          title: const Text('Save History'),
          onChanged: (value) => setState(() => _builderSaveHistory = value),
        ),
      ],
    );
  }

  Widget _buildKeyValueSection({
    required String title,
    required List<_KeyValueRow> rows,
    required VoidCallback onAdd,
    required void Function(int index) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 160,
                child: TextFormField(
                  initialValue: row.keyText,
                  decoration: const InputDecoration(labelText: 'Key'),
                  onChanged: (value) => row.keyText = value,
                ),
              ),
              SizedBox(
                width: 180,
                child: TextFormField(
                  initialValue: row.valueText,
                  decoration: const InputDecoration(labelText: 'Value'),
                  onChanged: (value) => row.valueText = value,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onRemove(index),
              ),
            ],
          );
        }),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
  void _addEmptyRule() {
    final newRule = {
      'name': 'New Rule',
      'condition': {
        'field': '',
        'operator': 'equals',
        'value': '',
      },
      'actions': [
        {'type': 'redirect', 'url': '', 'params': {}},
      ],
    };
    setState(() {
      _rules.add(newRule);
      _selectedRuleIndex = _rules.length - 1;
      _editorController.text = const JsonEncoder.withIndent('  ').convert(newRule);
      _error = null;
    });
    _loadBuilderFromRule(newRule);
    _tabController.animateTo(1);
  }

  void _selectRule(int index) {
    setState(() {
      _selectedRuleIndex = index;
      _editorController.text = const JsonEncoder.withIndent('  ').convert(_rules[index]);
      _error = null;
    });
    _loadBuilderFromRule(_rules[index]);
    _tabController.animateTo(1);
  }

  Future<void> _deleteRule(int index) async {
    setState(() {
      _rules.removeAt(index);
      if (_rules.isEmpty) {
        _selectedRuleIndex = null;
        _editorController.clear();
      } else if (_selectedRuleIndex != null) {
        if (_selectedRuleIndex! >= _rules.length) {
          _selectedRuleIndex = _rules.length - 1;
        }
        _editorController.text = const JsonEncoder.withIndent('  ').convert(_rules[_selectedRuleIndex!]);
      }
    });
    await _saveAllRules();
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          onPressed: _scanSampleAndGenerate,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Sample'),
        ),
        const SizedBox(height: 12),
        if (_rules.isEmpty)
          const Center(child: Text('No rules yet. Tap + to add a rule.'))
        else
          ..._rules.asMap().entries.map((entry) {
            final index = entry.key;
            final rule = entry.value;
            final name = rule['name']?.toString() ?? 'Rule ${index + 1}';
            return Card(
              child: ListTile(
                title: Text(name),
                subtitle: Text('Tap to edit'),
                onTap: () => _selectRule(index),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteRule(index),
                ),
              ),
            );
          }),
      ],
    );
  }
  Widget _buildEditorTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_selectedRuleIndex == null)
          const Center(child: Text('Select a rule to edit')),
        if (_selectedRuleIndex != null) _buildBuilderSection(),
        if (_error != null) const SizedBox(height: 8),
        if (_error != null)
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Raw JSON (two-way sync)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: TextField(
            controller: _editorController,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              labelText: 'Rule JSON',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _applyJsonToBuilder,
                icon: const Icon(Icons.sync),
                label: const Text('Apply JSON to Form'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _formatJson,
                icon: const Icon(Icons.format_align_left),
                label: const Text('Format JSON'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _scanSampleAndGenerate,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Sample'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _selectedRuleIndex == null ? null : _applyBuilderToRule,
          child: const Text('Save Rule'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saveAllRules,
          icon: const Icon(Icons.save),
          label: const Text('Save All Rules'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showJsonDialog,
          icon: const Icon(Icons.code),
          label: const Text('View JSON'),
        ),
      ],
    );
  }

  Widget _buildExamplesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ExampleCard(
          title: 'Redirect + Replace + Message',
          code: r'{'
              '\n  "rules": ['
              '\n    {'
              '\n      "name": "Pay Route",'
              '\n      "condition": {'
              '\n        "field": "type",'
              '\n        "operator": "equals",'
              '\n        "value": "payment"'
              '\n      },'
              '\n      "replace": {'
              '\n        "field_map": { "customer_code": "client_id" },'
              '\n        "value_map": { "type": { "payment": "pay" } }'
              '\n      },'
              '\n      "actions": ['
              '\n        {'
              '\n          "type": "redirect",'
              '\n          "url": "https://example.com/pay",'
              '\n          "params": {'
              '\n            "customer_id": "\$client_id",'
              '\n            "amount": "\$amount"'
              '\n          }'
              '\n        },'
              '\n        { "type": "show_message", "message": "Redirecting \$client_id" }'
              '\n      ]'
              '\n    }'
              '\n  ]'
              '\n}',
        ),
        const SizedBox(height: 12),
        _ExampleCard(
          title: 'Multi-Condition (AND)',
          code: r'{'
              '\n  "rules": ['
              '\n    {'
              '\n      "name": "Pay If High Amount",'
              '\n      "condition": {'
              '\n        "all": ['
              '\n          { "field": "type", "operator": "equals", "value": "payment" },'
              '\n          { "field": "amount", "operator": "gt", "value": 100 }'
              '\n        ]'
              '\n      },'
              '\n      "actions": ['
              '\n        { "type": "redirect", "url": "https://example.com/pay" }'
              '\n      ]'
              '\n    }'
              '\n  ]'
              '\n}',
        ),
        const SizedBox(height: 12),
        _ExampleCard(
          title: 'Multi-Condition (OR)',
          code: r'{'
              '\n  "rules": ['
              '\n    {'
              '\n      "name": "Status Success",'
              '\n      "condition": {'
              '\n        "any": ['
              '\n          { "field": "status", "operator": "equals", "value": "success" },'
              '\n          { "field": "status", "operator": "equals", "value": "paid" }'
              '\n        ]'
              '\n      },'
              '\n      "actions": ['
              '\n        { "type": "show_message", "message": "Payment OK" }'
              '\n      ]'
              '\n    }'
              '\n  ]'
              '\n}',
        ),
        const SizedBox(height: 12),
        _ExampleCard(
          title: 'API Call / Backend Hook',
          code: r'{'
              '\n  "rules": ['
              '\n    {'
              '\n      "name": "Notify Backend",'
              '\n      "condition": {'
              '\n        "field": "event",'
              '\n        "operator": "equals",'
              '\n        "value": "checkin"'
              '\n      },'
              '\n      "actions": ['
              '\n        {'
              '\n          "type": "api_call",'
              '\n          "url": "https://example.com/api/checkin",'
              '\n          "body": {'
              '\n            "user": "\$user_id",'
              '\n            "time": "\$timestamp"'
              '\n          }'
              '\n        }'
              '\n      ]'
              '\n    }'
              '\n  ]'
              '\n}',
        ),
      ],
    );
  }

  Widget _buildVariablesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Text('Variables', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(r'Use $key to insert JSON values. Nested keys use dot notation: $user.id'),
        SizedBox(height: 12),
        Text('Operators', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('equals, contains, exists, gt, lt, gte, lte, starts_with, ends_with, in'),
        SizedBox(height: 12),
        Text('Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('redirect, api_call, backend_hook, route, show_message, save_history'),
      ],
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({required this.title, required this.code});

  final String title;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            SelectableText(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionRow {
  _ConditionRow({required this.field, required this.operatorType, required this.value});
  String field;
  String operatorType;
  String value;
}

class _KeyValueRow {
  _KeyValueRow({this.keyText = '', this.valueText = ''});
  String keyText;
  String valueText;
}
