import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_settings.dart';
import '../utils/constants.dart';
import '../widgets/common_app_bar.dart';
import 'qr_import_screen.dart';

class GatewayRulesScreen extends StatefulWidget {
  const GatewayRulesScreen({Key? key}) : super(key: key);

  @override
  State<GatewayRulesScreen> createState() => _GatewayRulesScreenState();
}

class _GatewayRulesScreenState extends State<GatewayRulesScreen> {
  final AppSettings _settings = AppSettings.instance;
  final TextEditingController _editorController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _editorController.text = _settings.gatewayRulesJson;
  }

  @override
  void dispose() {
    _editorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _editorController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Editor is empty');
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic> || decoded['rules'] is! List) {
        setState(() => _error = 'Invalid rules format');
        return;
      }
      await _settings.setGatewayRulesJson(raw);
      setState(() => _error = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rules saved')),
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

    final firstKey = data.keys.first;
    final firstValue = data[firstKey];
    final params = <String, dynamic>{};
    data.forEach((key, value) {
      params[key] = '\$$key';
    });

    final generated = {
      'rules': [
        {
          'name': 'Auto Rule',
          'condition': {
            'field': firstKey,
            'operator': 'equals',
            'value': firstValue,
          },
          'action': {
            'type': 'redirect',
            'url': urlController.text.trim(),
            'params': params,
          },
        },
      ],
    };

    _editorController.text = const JsonEncoder.withIndent('  ').convert(generated);
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(title: AppConstants.appName),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Custom Gateway Rules Editor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _settings.gatewayRulesEnabled,
            title: const Text('Enable Custom Rules'),
            subtitle: const Text('Apply rules to JSON QR scans'),
            onChanged: (value) => _settings.setGatewayRulesEnabled(value),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: TextField(
              controller: _editorController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                labelText: 'Rules JSON',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save Rules'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scanSampleAndGenerate,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR Sample'),
          ),
          const SizedBox(height: 12),
          const Text(
            'Example format:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            r'{'
            '\n  "rules": ['
            '\n    {'
            '\n      "name": "Pay Route",'
            '\n      "condition": {'
            '\n        "field": "type",'
            '\n        "operator": "equals",'
            '\n        "value": "payment"'
            '\n      },'
            '\n      "action": {'
            '\n        "type": "redirect",'
            '\n        "url": "https://example.com/pay",'
            '\n        "params": {'
            '\n          "customer_id": "\$customer_code",'
            '\n          "amount": "\$amount"'
            '\n        }'
            '\n      }'
            '\n    }'
            '\n  ]'
            '\n}',
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
