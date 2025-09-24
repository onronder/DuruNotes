import 'package:intl/intl.dart';

/// Service for handling template variables and replacements
class TemplateVariableService {
  static final TemplateVariableService _instance = TemplateVariableService._internal();
  factory TemplateVariableService() => _instance;
  TemplateVariableService._internal();

  /// Variable pattern: {{variableName}} or {{variableName:default}}
  static final RegExp _variablePattern = RegExp(r'\{\{([^}:]+)(?::([^}]+))?\}\}');

  /// System variables that are automatically replaced
  final Map<String, String Function()> _systemVariables = {
    'date': () => DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'time': () => DateFormat('HH:mm').format(DateTime.now()),
    'datetime': () => DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    'year': () => DateTime.now().year.toString(),
    'month': () => DateFormat('MMMM').format(DateTime.now()),
    'day': () => DateTime.now().day.toString(),
    'weekday': () => DateFormat('EEEE').format(DateTime.now()),
    'timestamp': () => DateTime.now().millisecondsSinceEpoch.toString(),
  };

  /// Extract all variables from template body
  List<TemplateVariable> extractVariables(String templateBody) {
    final variables = <TemplateVariable>[];
    final matches = _variablePattern.allMatches(templateBody);

    for (final match in matches) {
      final name = match.group(1)!;
      final defaultValue = match.group(2);

      // Skip system variables
      if (_systemVariables.containsKey(name.toLowerCase())) {
        continue;
      }

      // Avoid duplicates
      if (!variables.any((v) => v.name == name)) {
        variables.add(TemplateVariable(
          name: name,
          defaultValue: defaultValue,
          type: _inferVariableType(name, defaultValue),
        ));
      }
    }

    return variables;
  }

  /// Replace variables in template body with provided values
  String replaceVariables(String templateBody, Map<String, String> userValues) {
    String result = templateBody;

    // Replace system variables first
    _systemVariables.forEach((name, getValue) {
      final pattern = RegExp('\\{\\{$name(?::[^}]+)?\\}\\}', caseSensitive: false);
      result = result.replaceAll(pattern, getValue());
    });

    // Replace user variables
    final matches = _variablePattern.allMatches(result);
    final replacements = <String, String>{};

    for (final match in matches) {
      final fullMatch = match.group(0)!;
      final name = match.group(1)!;
      final defaultValue = match.group(2) ?? '';

      // Skip if already processed
      if (replacements.containsKey(fullMatch)) {
        continue;
      }

      // Use user value, or default, or leave placeholder
      final value = userValues[name] ?? defaultValue;
      replacements[fullMatch] = value;
    }

    // Apply all replacements
    replacements.forEach((pattern, replacement) {
      result = result.replaceAll(pattern, replacement);
    });

    return result;
  }

  /// Get list of available system variables
  List<String> getSystemVariables() {
    return _systemVariables.keys.toList()..sort();
  }

  /// Infer variable type from name and default value
  VariableType _inferVariableType(String name, String? defaultValue) {
    final lowerName = name.toLowerCase();

    // Check common patterns
    if (lowerName.contains('date')) return VariableType.date;
    if (lowerName.contains('time')) return VariableType.time;
    if (lowerName.contains('email')) return VariableType.email;
    if (lowerName.contains('phone')) return VariableType.phone;
    if (lowerName.contains('url') || lowerName.contains('link')) return VariableType.url;
    if (lowerName.contains('number') || lowerName.contains('count')) return VariableType.number;

    // Check default value
    if (defaultValue != null) {
      if (RegExp(r'^\d+$').hasMatch(defaultValue)) return VariableType.number;
      if (defaultValue.contains('@')) return VariableType.email;
      if (defaultValue.startsWith('http')) return VariableType.url;
    }

    return VariableType.text;
  }

  /// Process template for quick preview
  String processForPreview(String templateBody) {
    return replaceVariables(templateBody, {});
  }
}

/// Template variable model
class TemplateVariable {
  final String name;
  final String? defaultValue;
  final VariableType type;

  const TemplateVariable({
    required this.name,
    this.defaultValue,
    required this.type,
  });
}

/// Variable types for input validation
enum VariableType {
  text,
  number,
  date,
  time,
  email,
  phone,
  url,
}

/// Extension for variable type helpers
extension VariableTypeX on VariableType {
  String get displayName {
    switch (this) {
      case VariableType.text:
        return 'Text';
      case VariableType.number:
        return 'Number';
      case VariableType.date:
        return 'Date';
      case VariableType.time:
        return 'Time';
      case VariableType.email:
        return 'Email';
      case VariableType.phone:
        return 'Phone';
      case VariableType.url:
        return 'URL';
    }
  }

  String get inputHint {
    switch (this) {
      case VariableType.text:
        return 'Enter text...';
      case VariableType.number:
        return 'Enter number...';
      case VariableType.date:
        return 'YYYY-MM-DD';
      case VariableType.time:
        return 'HH:MM';
      case VariableType.email:
        return 'example@email.com';
      case VariableType.phone:
        return '+1234567890';
      case VariableType.url:
        return 'https://example.com';
    }
  }
}