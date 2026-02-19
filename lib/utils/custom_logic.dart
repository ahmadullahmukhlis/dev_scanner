import 'dart:convert';

class CustomLogicRule {
  CustomLogicRule({
    required this.name,
    required this.condition,
    required this.actions,
    this.saveToHistory = false,
  });

  final String name;
  final CustomLogicCondition condition;
  final List<CustomLogicAction> actions;
  final bool saveToHistory;

  Map<String, dynamic> toJson() => {
        'name': name,
        'condition': condition.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'saveToHistory': saveToHistory,
      };

  factory CustomLogicRule.fromJson(Map<String, dynamic> json) {
    return CustomLogicRule(
      name: json['name']?.toString() ?? 'Rule',
      condition: CustomLogicCondition.fromJson(json['condition'] as Map<String, dynamic>? ?? {}),
      actions: (json['actions'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CustomLogicAction.fromJson)
          .toList(),
      saveToHistory: json['saveToHistory'] == true,
    );
  }
}

class CustomLogicCondition {
  CustomLogicCondition({
    required this.type,
    this.value,
    this.field,
  });

  final String type; // exact, contains, json_field_equals
  final String? value;
  final String? field;

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'field': field,
      };

  factory CustomLogicCondition.fromJson(Map<String, dynamic> json) {
    return CustomLogicCondition(
      type: json['type']?.toString() ?? 'contains',
      value: json['value']?.toString(),
      field: json['field']?.toString(),
    );
  }
}

class CustomLogicAction {
  CustomLogicAction({
    required this.type,
    this.value,
    this.fields,
    this.mapping,
  });

  final String type; // open_url, show_message, show_json_fields, sound, vibrate
  final String? value;
  final List<String>? fields;
  final Map<String, String>? mapping;

  Map<String, dynamic> toJson() => {
        'type': type,
        'value': value,
        'fields': fields,
        'mapping': mapping,
      };

  factory CustomLogicAction.fromJson(Map<String, dynamic> json) {
    final fieldsRaw = json['fields'];
    final mappingRaw = json['mapping'];
    Map<String, String>? mapping;
    if (mappingRaw is Map) {
      mapping = mappingRaw.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return CustomLogicAction(
      type: json['type']?.toString() ?? 'show_message',
      value: json['value']?.toString(),
      fields: fieldsRaw is List
          ? fieldsRaw.map((e) => e.toString()).toList()
          : fieldsRaw is String
              ? fieldsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : null,
      mapping: mapping,
    );
  }
}

class CustomLogicEngine {
  CustomLogicEngine(this.rules);

  final List<CustomLogicRule> rules;

  static List<CustomLogicRule> parseRules(String rawJson) {
    if (rawJson.trim().isEmpty) return [];
    final decoded = json.decode(rawJson);
    if (decoded is Map<String, dynamic> && decoded['rules'] is List) {
      return (decoded['rules'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CustomLogicRule.fromJson)
          .toList();
    }
    if (decoded is List) {
      return decoded.whereType<Map<String, dynamic>>().map(CustomLogicRule.fromJson).toList();
    }
    return [];
  }

  static String rulesToJson(List<CustomLogicRule> rules) {
    final payload = {'rules': rules.map((r) => r.toJson()).toList()};
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  CustomLogicRule? matchRule(String raw) {
    for (final rule in rules) {
      if (_matches(rule.condition, raw)) return rule;
    }
    return null;
  }

  bool _matches(CustomLogicCondition condition, String raw) {
    final value = condition.value ?? '';
    switch (condition.type) {
      case 'exact':
        return raw == value;
      case 'contains':
        return raw.contains(value);
      case 'json_field_equals':
        final json = _parseJson(raw);
        if (json == null) return false;
        final fieldValue = _getJsonPathValue(json, condition.field);
        return fieldValue != null && fieldValue.toString() == value;
      default:
        return false;
    }
  }

  Map<String, dynamic>? _parseJson(String raw) {
    try {
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  dynamic _getJsonPathValue(Map<String, dynamic> json, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    dynamic current = json;
    for (final part in path.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  static Map<String, dynamic>? tryParseJson(String raw) {
    try {
      final decoded = json.decode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String? resolveValue(String raw, Map<String, dynamic>? json, String? template) {
    if (template == null || template.trim().isEmpty) return raw;
    final trimmed = template.trim();
    if (trimmed == '{raw}' || trimmed == 'raw') return raw;
    if (trimmed.startsWith('field:')) {
      final path = trimmed.substring('field:'.length).trim();
      if (json == null) return null;
      return _getStaticJsonPathValue(json, path)?.toString();
    }
    if (trimmed.startsWith('{field:') && trimmed.endsWith('}')) {
      final path = trimmed.substring(7, trimmed.length - 1).trim();
      if (json == null) return null;
      return _getStaticJsonPathValue(json, path)?.toString();
    }
    var result = template.replaceAll('{raw}', raw);
    if (json != null && result.contains('{field:')) {
      final regex = RegExp(r'\{field:([^}]+)\}');
      result = result.replaceAllMapped(regex, (match) {
        final path = match.group(1)?.trim() ?? '';
        final value = _getStaticJsonPathValue(json, path);
        return value?.toString() ?? '';
      });
    }
    return result;
  }

  static Map<String, String> resolveMapping(String raw, Map<String, dynamic>? json, Map<String, String> mapping) {
    final resolved = <String, String>{};
    for (final entry in mapping.entries) {
      final value = resolveValue(raw, json, entry.value) ?? '';
      resolved[entry.key] = value;
    }
    return resolved;
  }

  static dynamic _getStaticJsonPathValue(Map<String, dynamic> json, String path) {
    dynamic current = json;
    for (final part in path.split('.')) {
      if (current is Map<String, dynamic> && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }
}
