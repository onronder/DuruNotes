import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:duru_notes/services/template_variable_service.dart';
import 'package:duru_notes/theme/cross_platform_tokens.dart';
import 'package:intl/intl.dart';

/// Dialog for inputting template variable values
class TemplateVariableDialog extends StatefulWidget {
  final List<TemplateVariable> variables;
  final String templateTitle;

  const TemplateVariableDialog({
    super.key,
    required this.variables,
    required this.templateTitle,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required List<TemplateVariable> variables,
    required String templateTitle,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => TemplateVariableDialog(
        variables: variables,
        templateTitle: templateTitle,
      ),
    );
  }

  @override
  State<TemplateVariableDialog> createState() => _TemplateVariableDialogState();
}

class _TemplateVariableDialogState extends State<TemplateVariableDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _values;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controllers = {};
    _values = {};

    for (final variable in widget.variables) {
      _controllers[variable.name] = TextEditingController(
        text: variable.defaultValue ?? '',
      );
      _values[variable.name] = variable.defaultValue ?? '';
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DuruColors.primary,
                    DuruColors.accent.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.text_badge_star,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Fill Template Variables',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For template: ${widget.templateTitle}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      for (final variable in widget.variables) ...[
                        _buildVariableInput(variable),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [DuruColors.primary, DuruColors.accent],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: _onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Apply',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariableInput(TemplateVariable variable) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: DuruColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                variable.name,
                style: TextStyle(
                  color: DuruColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              variable.type.displayName,
              style: TextStyle(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (variable.type == VariableType.date)
          _buildDateInput(variable)
        else if (variable.type == VariableType.time)
          _buildTimeInput(variable)
        else
          TextFormField(
            controller: _controllers[variable.name],
            decoration: InputDecoration(
              hintText: variable.type.inputHint,
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            keyboardType: _getKeyboardType(variable.type),
            validator: (value) => _validateInput(value, variable.type),
            onChanged: (value) => _values[variable.name] = value,
          ),
      ],
    );
  }

  Widget _buildDateInput(TemplateVariable variable) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (date != null) {
          final formatted = DateFormat('yyyy-MM-dd').format(date);
          _controllers[variable.name]!.text = formatted;
          _values[variable.name] = formatted;
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: _controllers[variable.name],
          decoration: InputDecoration(
            hintText: 'Tap to select date',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Icon(
              CupertinoIcons.calendar,
              color: DuruColors.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInput(TemplateVariable variable) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
        );
        if (time != null && mounted) {
          final formatted = time.format(context);
          _controllers[variable.name]!.text = formatted;
          _values[variable.name] = formatted;
        }
      },
      child: AbsorbPointer(
        child: TextFormField(
          controller: _controllers[variable.name],
          decoration: InputDecoration(
            hintText: 'Tap to select time',
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Icon(
              CupertinoIcons.clock,
              color: DuruColors.primary,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  TextInputType _getKeyboardType(VariableType type) {
    switch (type) {
      case VariableType.number:
        return TextInputType.number;
      case VariableType.email:
        return TextInputType.emailAddress;
      case VariableType.phone:
        return TextInputType.phone;
      case VariableType.url:
        return TextInputType.url;
      default:
        return TextInputType.text;
    }
  }

  String? _validateInput(String? value, VariableType type) {
    if (value == null || value.isEmpty) {
      return null; // Allow empty values
    }

    switch (type) {
      case VariableType.email:
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        break;
      case VariableType.url:
        if (!value.startsWith('http://') && !value.startsWith('https://')) {
          return 'Please enter a valid URL';
        }
        break;
      case VariableType.number:
        if (double.tryParse(value) == null) {
          return 'Please enter a valid number';
        }
        break;
      default:
        break;
    }
    return null;
  }

  void _onApply() {
    if (_formKey.currentState!.validate()) {
      // Collect all values
      final result = <String, String>{};
      for (final variable in widget.variables) {
        result[variable.name] = _controllers[variable.name]!.text;
      }
      Navigator.of(context).pop(result);
    }
  }
}