import 'dart:convert';
import 'package:http/http.dart' as http;

class QrRuleResult {
  QrRuleResult({
    required this.allowed,
    required this.message,
    this.redirectUrl,
    this.mappedData,
    this.showResult = false,
  });

  final bool allowed;
  final String message;
  final String? redirectUrl;
  final Map<String, dynamic>? mappedData;
  final bool showResult;
}

class QrRuleEngine {
  static Future<QrRuleResult> process(String raw) async {
    final parsed = _safeJson(raw);
    if (parsed == null) {
      return QrRuleResult(allowed: false, message: 'Invalid JSON');
    }

    final token = parsed['token'];
    if (token == null || token.toString().trim().isEmpty) {
      return QrRuleResult(allowed: false, message: 'Missing token');
    }

    final verified = await _verifyWithBackend(raw);
    if (!verified) {
      return QrRuleResult(allowed: false, message: 'Verification failed');
    }

    final rules = parsed['rules'] as Map<String, dynamic>? ?? {};
    final data = (parsed['data'] is Map<String, dynamic>) ? Map<String, dynamic>.from(parsed['data']) : <String, dynamic>{};

    final replacedData = _applyReplace(rules['replace'] as Map<String, dynamic>?, data);

    final condition = rules['condition'] as Map<String, dynamic>?;
    final conditionPassed = _applyCondition(condition, replacedData);

    final redirect = rules['redirect'] as Map<String, dynamic>?;
    if (conditionPassed && redirect != null) {
      final url = _buildRedirectUrl(redirect, replacedData);
      return QrRuleResult(
        allowed: true,
        message: 'Redirect allowed',
        redirectUrl: url,
        mappedData: replacedData,
        showResult: rules['show_result'] == true,
      );
    }

    return QrRuleResult(
      allowed: conditionPassed,
      message: conditionPassed ? 'Condition met' : 'Condition not met',
      mappedData: replacedData,
      showResult: rules['show_result'] == true,
    );
  }

  static Map<String, dynamic>? _safeJson(String raw) {
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _verifyWithBackend(String raw) async {
    final uri = Uri.parse('https://myapi.com/verify-scan');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: raw,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final status = decoded['status'];
        return status == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _applyReplace(Map<String, dynamic>? replace, Map<String, dynamic> data) {
    if (replace == null) return data;
    var output = Map<String, dynamic>.from(data);

    final fieldMap = replace['field_map'];
    if (fieldMap is Map) {
      final updated = <String, dynamic>{};
      output.forEach((key, value) {
        final newKey = fieldMap[key]?.toString() ?? key;
        updated[newKey] = value;
      });
      output = updated;
    }

    final valueMap = replace['value_map'];
    if (valueMap is Map) {
      valueMap.forEach((key, mapValue) {
        if (output.containsKey(key) && mapValue is Map) {
          final current = output[key];
          final mapped = mapValue[current?.toString()];
          if (mapped != null) {
            output[key] = mapped;
          }
        }
      });
    }

    return output;
  }

  static bool _applyCondition(Map<String, dynamic>? condition, Map<String, dynamic> data) {
    if (condition == null) return false;
    final field = condition['field']?.toString();
    final equals = condition['equals'];
    if (field == null || field.isEmpty) return false;
    if (!data.containsKey(field)) return false;
    return data[field].toString() == equals.toString();
  }

  static String _buildRedirectUrl(Map<String, dynamic> redirect, Map<String, dynamic> data) {
    final baseUrl = redirect['url']?.toString() ?? '';
    final params = redirect['params'];
    if (baseUrl.isEmpty || params is! Map) return baseUrl;
    final query = <String, String>{};
    params.forEach((key, value) {
      final template = value?.toString() ?? '';
      query[key.toString()] = _replaceTokens(template, data);
    });
    final uri = Uri.parse(baseUrl);
    final merged = Map<String, String>.from(uri.queryParameters)..addAll(query);
    return uri.replace(queryParameters: merged).toString();
  }

  static String _replaceTokens(String template, Map<String, dynamic> data) {
    return template.replaceAllMapped(RegExp(r'\$([a-zA-Z0-9_]+)'), (match) {
      final key = match.group(1);
      if (key == null) return '';
      return data[key]?.toString() ?? '';
    });
  }
}
