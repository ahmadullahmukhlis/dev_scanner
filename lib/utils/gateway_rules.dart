import 'dart:convert';
import 'package:http/http.dart' as http;

class GatewayRuleSet {
  GatewayRuleSet({required this.rules});
  final List<GatewayRule> rules;

  factory GatewayRuleSet.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'];
    if (rawRules is List) {
      return GatewayRuleSet(
        rules: rawRules.whereType<Map<String, dynamic>>().map(GatewayRule.fromJson).toList(),
      );
    }
    return GatewayRuleSet(rules: []);
  }
}

class GatewayRule {
  GatewayRule({
    required this.name,
    required this.condition,
    required this.action,
  });

  final String name;
  final RuleCondition condition;
  final RuleAction action;

  factory GatewayRule.fromJson(Map<String, dynamic> json) {
    return GatewayRule(
      name: json['name']?.toString() ?? 'Rule',
      condition: RuleCondition.fromJson(json['condition'] as Map<String, dynamic>? ?? {}),
      action: RuleAction.fromJson(json['action'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class RuleCondition {
  RuleCondition({
    required this.field,
    required this.operatorType,
    this.value,
  });

  final String field;
  final String operatorType; // equals, contains, exists, gt, lt
  final dynamic value;

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      field: json['field']?.toString() ?? '',
      operatorType: json['operator']?.toString() ?? 'equals',
      value: json['value'],
    );
  }
}

class RuleAction {
  RuleAction({
    required this.type,
    this.url,
    this.params,
    this.body,
    this.route,
  });

  final String type; // redirect, api_call, route, backend_hook
  final String? url;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? body;
  final String? route;

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      type: json['type']?.toString() ?? 'redirect',
      url: json['url']?.toString(),
      params: json['params'] is Map ? Map<String, dynamic>.from(json['params']) : null,
      body: json['body'] is Map ? Map<String, dynamic>.from(json['body']) : null,
      route: json['route']?.toString(),
    );
  }
}

class GatewayRuleResult {
  GatewayRuleResult({
    required this.matched,
    this.action,
    this.message,
  });

  final bool matched;
  final RuleAction? action;
  final String? message;
}

class GatewayRuleEngine {
  static GatewayRuleResult evaluate(Map<String, dynamic> data, GatewayRuleSet ruleSet) {
    for (final rule in ruleSet.rules) {
      if (_matches(rule.condition, data)) {
        return GatewayRuleResult(matched: true, action: rule.action, message: rule.name);
      }
    }
    return GatewayRuleResult(matched: false);
  }

  static bool _matches(RuleCondition condition, Map<String, dynamic> data) {
    if (condition.field.trim().isEmpty) return false;
    final fieldValue = _getByPath(data, condition.field);
    switch (condition.operatorType) {
      case 'exists':
        return fieldValue != null;
      case 'contains':
        return fieldValue?.toString().contains(condition.value?.toString() ?? '') ?? false;
      case 'gt':
        return _compare(fieldValue, condition.value) > 0;
      case 'lt':
        return _compare(fieldValue, condition.value) < 0;
      case 'equals':
      default:
        return fieldValue?.toString() == condition.value?.toString();
    }
  }

  static int _compare(dynamic a, dynamic b) {
    final aNum = num.tryParse(a?.toString() ?? '');
    final bNum = num.tryParse(b?.toString() ?? '');
    if (aNum == null || bNum == null) return 0;
    return aNum.compareTo(bNum);
  }

  static dynamic _getByPath(Map<String, dynamic> data, String path) {
    dynamic current = data;
    for (final part in path.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  static String applyTemplate(String template, Map<String, dynamic> data) {
    return template.replaceAllMapped(RegExp(r'\$([a-zA-Z0-9_.]+)'), (match) {
      final key = match.group(1);
      if (key == null) return '';
      final value = _getByPath(data, key);
      return value?.toString() ?? '';
    });
  }

  static Map<String, dynamic> applyTemplateToMap(Map<String, dynamic> input, Map<String, dynamic> data) {
    final output = <String, dynamic>{};
    input.forEach((key, value) {
      if (value is String) {
        output[key] = applyTemplate(value, data);
      } else {
        output[key] = value;
      }
    });
    return output;
  }

  static Future<bool> callApi(String url, Map<String, dynamic> body) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
