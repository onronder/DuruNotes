import 'package:duru_notes/features/folders/smart_folders/smart_folder_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class SmartFolderCreator extends ConsumerStatefulWidget {
  const SmartFolderCreator({super.key, this.initialConfig});

  final SmartFolderConfig? initialConfig;

  @override
  ConsumerState<SmartFolderCreator> createState() => _SmartFolderCreatorState();
}

class _SmartFolderCreatorState extends ConsumerState<SmartFolderCreator> {
  late TextEditingController _nameController;
  late SmartFolderType _selectedType;
  late List<SmartFolderRule> _rules;
  late bool _combineWithAnd;
  IconData? _customIcon;
  Color? _customColor;
  late int _maxResults;
  late bool _autoRefresh;
  Duration _refreshInterval = const Duration(minutes: 5);

  @override
  void initState() {
    super.initState();

    final config = widget.initialConfig;
    _nameController = TextEditingController(text: config?.name ?? '');
    _selectedType = config?.type ?? SmartFolderType.custom;
    _rules = config?.rules.toList() ?? [];
    _combineWithAnd = config?.combineWithAnd ?? true;
    _customIcon = config?.customIcon;
    _customColor = config?.customColor;
    _maxResults = config?.maxResults ?? 100;
    _autoRefresh = config?.autoRefresh ?? true;
    _refreshInterval = config?.refreshInterval ?? const Duration(minutes: 5);

    // Add initial rule if empty
    if (_rules.isEmpty) {
      _addRule();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addRule() {
    setState(() {
      _rules.add(
        SmartFolderRule(
          id: const Uuid().v4(),
          field: RuleField.title,
          operator: RuleOperator.contains,
        ),
      );
    });
  }

  void _removeRule(String ruleId) {
    setState(() {
      _rules.removeWhere((r) => r.id == ruleId);
      if (_rules.isEmpty) {
        _addRule();
      }
    });
  }

  void _updateRule(String ruleId, SmartFolderRule updatedRule) {
    setState(() {
      final index = _rules.indexWhere((r) => r.id == ruleId);
      if (index != -1) {
        _rules[index] = updatedRule;
      }
    });
  }

  void _selectTemplate(SmartFolderConfig template) {
    setState(() {
      _nameController.text = template.name;
      _selectedType = template.type;
      _rules = template.rules
          .map((r) => r.copyWith(id: const Uuid().v4()))
          .toList();
      _combineWithAnd = template.combineWithAnd;
    });
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a folder name')),
      );
      return false;
    }

    for (final rule in _rules) {
      if (rule.value == null &&
          rule.operator != RuleOperator.isEmpty &&
          rule.operator != RuleOperator.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete all rule conditions')),
        );
        return false;
      }
    }

    return true;
  }

  void _save() {
    if (!_validate()) return;

    final config = SmartFolderConfig(
      id: widget.initialConfig?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      type: _selectedType,
      rules: _rules,
      combineWithAnd: _combineWithAnd,
      customIcon: _customIcon ?? _selectedType.icon,
      customColor: _customColor ?? _selectedType.color,
      maxResults: _maxResults,
      autoRefresh: _autoRefresh,
      refreshInterval: _autoRefresh ? _refreshInterval : null,
    );

    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.initialConfig != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Smart Folder' : 'Create Smart Folder'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Templates section (only for new folders)
            if (!isEditing) ...[
              Text('Start with a template', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: SmartFolderTemplates.all.length,
                  itemBuilder: (context, index) {
                    final template = SmartFolderTemplates.all[index];
                    return _TemplateCard(
                      template: template,
                      onTap: () => _selectTemplate(template),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Basic info
            Text('Folder Details', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Folder Name',
                hintText: 'Enter a name for this smart folder',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Folder type
            DropdownButtonFormField<SmartFolderType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Folder Type',
                border: OutlineInputBorder(),
              ),
              items: SmartFolderType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(type.icon, size: 20, color: type.color),
                      const SizedBox(width: 8),
                      Text(type.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (type) {
                if (type != null) {
                  setState(() => _selectedType = type);
                }
              },
            ),

            const SizedBox(height: 24),

            // Rules section
            Row(
              children: [
                Text('Rules', style: theme.textTheme.titleMedium),
                const SizedBox(width: 16),
                if (_rules.length > 1) ...[
                  const Text('Match'),
                  const SizedBox(width: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('All')),
                      ButtonSegment(value: false, label: Text('Any')),
                    ],
                    selected: {_combineWithAnd},
                    onSelectionChanged: (selection) {
                      setState(() => _combineWithAnd = selection.first);
                    },
                  ),
                ],
                const Spacer(),
                IconButton(
                  onPressed: _addRule,
                  icon: const Icon(Icons.add_circle),
                  tooltip: 'Add Rule',
                ),
              ],
            ),

            const SizedBox(height: 12),

            ...List.generate(_rules.length, (index) {
              final rule = _rules[index];
              return _RuleBuilder(
                key: ValueKey(rule.id),
                rule: rule,
                onChanged: (updated) => _updateRule(rule.id, updated),
                onRemove: _rules.length > 1 ? () => _removeRule(rule.id) : null,
              );
            }),

            const SizedBox(height: 24),

            // Advanced settings
            ExpansionTile(
              title: const Text('Advanced Settings'),
              children: [
                ListTile(
                  title: const Text('Max Results'),
                  subtitle: Text('Limit to $_maxResults notes'),
                  trailing: SizedBox(
                    width: 100,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      controller: TextEditingController(
                        text: _maxResults.toString(),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null && parsed > 0) {
                          setState(() => _maxResults = parsed);
                        }
                      },
                    ),
                  ),
                ),

                SwitchListTile(
                  title: const Text('Auto Refresh'),
                  subtitle: const Text('Update folder contents automatically'),
                  value: _autoRefresh,
                  onChanged: (value) {
                    setState(() => _autoRefresh = value);
                  },
                ),

                if (_autoRefresh)
                  ListTile(
                    title: const Text('Refresh Interval'),
                    subtitle: Text(_formatDuration(_refreshInterval)),
                    trailing: PopupMenuButton<Duration>(
                      onSelected: (duration) {
                        setState(() => _refreshInterval = duration);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: Duration(minutes: 1),
                          child: Text('Every minute'),
                        ),
                        const PopupMenuItem(
                          value: Duration(minutes: 5),
                          child: Text('Every 5 minutes'),
                        ),
                        const PopupMenuItem(
                          value: Duration(minutes: 15),
                          child: Text('Every 15 minutes'),
                        ),
                        const PopupMenuItem(
                          value: Duration(hours: 1),
                          child: Text('Every hour'),
                        ),
                      ],
                    ),
                  ),

                ListTile(
                  title: const Text('Custom Icon'),
                  subtitle: const Text('Choose a custom icon'),
                  trailing: CircleAvatar(
                    backgroundColor: (_customColor ?? _selectedType.color)
                        .withValues(alpha: 0.2),
                    child: Icon(
                      _customIcon ?? _selectedType.icon,
                      color: _customColor ?? _selectedType.color,
                    ),
                  ),
                  onTap: _selectIcon,
                ),

                ListTile(
                  title: const Text('Custom Color'),
                  subtitle: const Text('Choose a custom color'),
                  trailing: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _customColor ?? _selectedType.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onTap: _selectColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return 'Every ${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else if (duration.inMinutes > 0) {
      return 'Every ${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Every ${duration.inSeconds} seconds';
    }
  }

  Future<void> _selectIcon() async {
    // Simplified icon picker - in production you'd want a proper icon picker widget
    final icons = [
      Icons.star,
      Icons.bookmark,
      Icons.label,
      Icons.flag,
      Icons.favorite,
      Icons.access_time,
      Icons.archive,
      Icons.folder_special,
    ];

    final selected = await showDialog<IconData>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Icon'),
        content: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: icons.map((icon) {
            return InkWell(
              onTap: () => Navigator.of(context).pop(icon),
              child: CircleAvatar(child: Icon(icon)),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _customIcon = selected);
    }
  }

  Future<void> _selectColor() async {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
    ];

    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors.map((color) {
            return InkWell(
              onTap: () => Navigator.of(context).pop(color),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _customColor = selected);
    }
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final SmartFolderConfig template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(template.type.icon, color: template.type.color, size: 32),
              const SizedBox(height: 8),
              Text(
                template.name,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleBuilder extends StatelessWidget {
  const _RuleBuilder({
    required this.rule,
    required this.onChanged,
    super.key,
    this.onRemove,
  });

  final SmartFolderRule rule;
  final Function(SmartFolderRule) onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Field selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<RuleField>(
                    initialValue: rule.field,
                    decoration: const InputDecoration(
                      labelText: 'Field',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: RuleField.values.map((field) {
                      return DropdownMenuItem(
                        value: field,
                        child: Text(field.displayName),
                      );
                    }).toList(),
                    onChanged: (field) {
                      if (field != null) {
                        // Reset operator when field changes
                        final availableOps = field.availableOperators;
                        final newOp = availableOps.contains(rule.operator)
                            ? rule.operator
                            : availableOps.first;
                        onChanged(rule.copyWith(field: field, operator: newOp));
                      }
                    },
                  ),
                ),

                const SizedBox(width: 8),

                // Operator selector
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<RuleOperator>(
                    initialValue: rule.operator,
                    decoration: const InputDecoration(
                      labelText: 'Condition',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: rule.field.availableOperators.map((op) {
                      return DropdownMenuItem(
                        value: op,
                        child: Text(op.displayName),
                      );
                    }).toList(),
                    onChanged: (op) {
                      if (op != null) {
                        onChanged(rule.copyWith(operator: op));
                      }
                    },
                  ),
                ),

                if (onRemove != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.remove_circle),
                    color: Colors.red,
                  ),
                ],
              ],
            ),

            // Value input(s)
            if (rule.operator != RuleOperator.isEmpty &&
                rule.operator != RuleOperator.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildValueInput(context, rule),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildValueInput(BuildContext context, SmartFolderRule rule) {
    final fieldType = rule.field.valueType;

    if (rule.operator == RuleOperator.between) {
      // Two value inputs for 'between' operator
      return Row(
        children: [
          Expanded(
            child: _buildSingleValueInput(context, fieldType, rule.value, (
              value,
            ) {
              onChanged(rule.copyWith(value: value));
            }, 'From'),
          ),
          const SizedBox(width: 8),
          const Text('to'),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSingleValueInput(
              context,
              fieldType,
              rule.secondValue,
              (value) {
                onChanged(rule.copyWith(secondValue: value));
              },
              'To',
            ),
          ),
        ],
      );
    } else {
      // Single value input
      return _buildSingleValueInput(context, fieldType, rule.value, (value) {
        onChanged(rule.copyWith(value: value));
      }, 'Value');
    }
  }

  Widget _buildSingleValueInput(
    BuildContext context,
    Type fieldType,
    dynamic currentValue,
    Function(dynamic) onValueChanged,
    String label,
  ) {
    if (fieldType == bool) {
      return DropdownButtonFormField<bool>(
        initialValue: currentValue as bool?,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: true, child: Text('Yes')),
          DropdownMenuItem(value: false, child: Text('No')),
        ],
        onChanged: onValueChanged,
      );
    } else if (fieldType == DateTime) {
      return InkWell(
        onTap: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: currentValue as DateTime? ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (date != null) {
            onValueChanged(date);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: Text(
            currentValue != null
                ? '${(currentValue as DateTime).day}/${currentValue.month}/${currentValue.year}'
                : 'Select date',
          ),
        ),
      );
    } else if (fieldType == int) {
      return TextField(
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: currentValue?.toString() ?? ''),
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null) {
            onValueChanged(parsed);
          }
        },
      );
    } else {
      // String input
      return TextField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        controller: TextEditingController(text: currentValue?.toString() ?? ''),
        onChanged: onValueChanged,
      );
    }
  }
}
