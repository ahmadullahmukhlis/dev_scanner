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
    required this.actions,
    this.replace,
  });

  final String name;
  final RuleCondition condition;
  final List<RuleAction> actions;
  final RuleReplace? replace;

  factory GatewayRule.fromJson(Map<String, dynamic> json) {
    final actionsRaw = json['actions'];
    return GatewayRule(
      name: json['name']?.toString() ?? 'Rule',
      condition: RuleCondition.fromJson(json['condition'] as Map<String, dynamic>? ?? {}),
      actions: actionsRaw is List
          ? actionsRaw.whereType<Map<String, dynamic>>().map(RuleAction.fromJson).toList()
          : [
              RuleAction.fromJson(json['action'] as Map<String, dynamic>? ?? {}),
            ],
      replace: json['replace'] is Map<String, dynamic> ? RuleReplace.fromJson(json['replace']) : null,
    );
  }
}

class RuleCondition {
  RuleCondition({
    this.field,
    this.operatorType,
    this.value,
    this.all,
    this.any,
    this.not,
  });

  final String? field;
  final String? operatorType; // equals, contains, exists, gt, lt, gte, lte, starts_with, ends_with, in
  final dynamic value;
  final List<RuleCondition>? all;
  final List<RuleCondition>? any;
  final RuleCondition? not;

  factory RuleCondition.fromJson(Map<String, dynamic> json) {
    return RuleCondition(
      field: json['field']?.toString(),
      operatorType: json['operator']?.toString(),
      value: json['value'],
      all: (json['all'] is List)
          ? (json['all'] as List)
              .whereType<Map<String, dynamic>>()
              .map(RuleCondition.fromJson)
              .toList()
          : null,
      any: (json['any'] is List)
          ? (json['any'] as List)
              .whereType<Map<String, dynamic>>()
              .map(RuleCondition.fromJson)
              .toList()
          : null,
      not: json['not'] is Map<String, dynamic> ? RuleCondition.fromJson(json['not']) : null,
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
    this.message,
  });

  final String type; // redirect, api_call, route, backend_hook, show_message, save_history
  final String? url;
  final Map<String, dynamic>? params;
  final Map<String, dynamic>? body;
  final String? route;
  final String? message;

  factory RuleAction.fromJson(Map<String, dynamic> json) {
    return RuleAction(
      type: json['type']?.toString() ?? 'redirect',
      url: json['url']?.toString(),
      params: json['params'] is Map ? Map<String, dynamic>.from(json['params']) : null,
      body: json['body'] is Map ? Map<String, dynamic>.from(json['body']) : null,
      route: json['route']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class RuleReplace {
  RuleReplace({
    required this.fieldMap,
    required this.valueMap,
  });

  final Map<String, String> fieldMap;
  final Map<String, Map<String, String>> valueMap;

  factory RuleReplace.fromJson(Map<String, dynamic> json) {
    final fieldMapRaw = json['field_map'];
    final valueMapRaw = json['value_map'];
    final fieldMap = fieldMapRaw is Map
        ? fieldMapRaw.map((key, value) => MapEntry(key.toString(), value.toString()))
        : <String, String>{};
    final valueMap = <String, Map<String, String>>{};
    if (valueMapRaw is Map) {
      valueMapRaw.forEach((key, value) {
        if (value is Map) {
          valueMap[key.toString()] = value.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
      });
    }
    return RuleReplace(fieldMap: fieldMap, valueMap: valueMap);
  }
}

class GatewayRuleResult {
  GatewayRuleResult({
    required this.matched,
    this.actions,
    this.mappedData,
    this.message,
  });

  final bool matched;
  final List<RuleAction>? actions;
  final Map<String, dynamic>? mappedData;
  final String? message;
}

class GatewayRuleEngine {
  static GatewayRuleResult evaluate(Map<String, dynamic> data, GatewayRuleSet ruleSet) {
    for (final rule in ruleSet.rules) {
      if (_matches(rule.condition, data)) {
        final mapped = _applyReplace(rule.replace, data);
        return GatewayRuleResult(
          matched: true,
          actions: rule.actions,
          mappedData: mapped,
          message: rule.name,
        );
      }
    }
    return GatewayRuleResult(matched: false);
  }

  static bool _matches(RuleCondition condition, Map<String, dynamic> data) {
    if (condition.all != null && condition.all!.isNotEmpty) {
      return condition.all!.every((c) => _matches(c, data));
    }
    if (condition.any != null && condition.any!.isNotEmpty) {
      return condition.any!.any((c) => _matches(c, data));
    }
    if (condition.not != null) {
      return !_matches(condition.not!, data);
    }
    final field = condition.field;
    if (field == null || field.trim().isEmpty) return false;
    final fieldValue = _getByPath(data, field);
    switch (condition.operatorType ?? 'equals') {
      case 'exists':
        return fieldValue != null;
      case 'starts_with':
        return fieldValue?.toString().startsWith(condition.value?.toString() ?? '') ?? false;
      case 'ends_with':
        return fieldValue?.toString().endsWith(condition.value?.toString() ?? '') ?? false;
      case 'contains':
        return fieldValue?.toString().contains(condition.value?.toString() ?? '') ?? false;
      case 'gt':
        return _compare(fieldValue, condition.value) > 0;
      case 'lt':
        return _compare(fieldValue, condition.value) < 0;
      case 'gte':
        return _compare(fieldValue, condition.value) >= 0;
      case 'lte':
        return _compare(fieldValue, condition.value) <= 0;
      case 'in':
        if (condition.value is List) {
          return (condition.value as List).map((e) => e.toString()).contains(fieldValue?.toString());
        }
        return false;
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

  static Map<String, dynamic> _applyReplace(RuleReplace? replace, Map<String, dynamic> data) {
    if (replace == null) return Map<String, dynamic>.from(data);
    var output = Map<String, dynamic>.from(data);
    if (replace.fieldMap.isNotEmpty) {
      final updated = <String, dynamic>{};
      output.forEach((key, value) {
        final newKey = replace.fieldMap[key] ?? key;
        updated[newKey] = value;
      });
      output = updated;
    }
    if (replace.valueMap.isNotEmpty) {
      replace.valueMap.forEach((field, map) {
        if (output.containsKey(field)) {
          final current = output[field]?.toString();
          final mapped = map[current];
          if (mapped != null) {
            output[field] = mapped;
          }
        }
      });
    }
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
