import 'package:duru_notes/models/note_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CodeBlockWidget extends StatefulWidget {
  const CodeBlockWidget({
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
    super.key,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;

  @override
  State<CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<CodeBlockWidget> {
  late TextEditingController _codeController;
  late TextEditingController _languageController;
  late FocusNode _codeFocusNode;
  late FocusNode _languageFocusNode;
  late String _language;
  late String _code;

  @override
  void initState() {
    super.initState();
    _parseCodeData();
    _codeController = TextEditingController(text: _code);
    _languageController = TextEditingController(text: _language);
    _codeFocusNode = FocusNode();
    _languageFocusNode = FocusNode();

    _codeFocusNode.addListener(() {
      widget.onFocusChanged(_codeFocusNode.hasFocus);
    });

    if (widget.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _codeFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(CodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.block.data != oldWidget.block.data) {
      _parseCodeData();
      _codeController.text = _code;
      _languageController.text = _language;
    }

    if (widget.isFocused && !oldWidget.isFocused) {
      _codeFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _languageController.dispose();
    _codeFocusNode.dispose();
    _languageFocusNode.dispose();
    super.dispose();
  }

  void _parseCodeData() {
    final parts = widget.block.data.split('\n');
    if (parts.length > 1 && !parts[0].contains(' ')) {
      _language = parts[0];
      _code = parts.skip(1).join('\n');
    } else {
      _language = '';
      _code = widget.block.data;
    }
  }

  void _updateCode() {
    final codeData = _language.isEmpty ? _code : '$_language\n$_code';
    final newBlock = widget.block.copyWith(data: codeData);
    widget.onChanged(newBlock);
  }

  void _handleCodeChanged() {
    _code = _codeController.text;
    _updateCode();
  }

  void _handleLanguageChanged() {
    _language = _languageController.text;
    _updateCode();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with language selector and actions
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                // Language Field
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _languageController,
                    focusNode: _languageFocusNode,
                    onChanged: (_) => _handleLanguageChanged(),
                    decoration: const InputDecoration(
                      hintText: 'Language',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),

                const Spacer(),

                // Copy Button
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: _copyToClipboard,
                  tooltip: 'Copy code',
                ),

                // Language Selector
                PopupMenuButton<String>(
                  icon: const Icon(Icons.language, size: 16),
                  onSelected: (language) {
                    _languageController.text = language;
                    _handleLanguageChanged();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'dart', child: Text('Dart')),
                    const PopupMenuItem(
                      value: 'javascript',
                      child: Text('JavaScript'),
                    ),
                    const PopupMenuItem(
                      value: 'typescript',
                      child: Text('TypeScript'),
                    ),
                    const PopupMenuItem(value: 'python', child: Text('Python')),
                    const PopupMenuItem(value: 'java', child: Text('Java')),
                    const PopupMenuItem(value: 'cpp', child: Text('C++')),
                    const PopupMenuItem(value: 'json', child: Text('JSON')),
                    const PopupMenuItem(value: 'yaml', child: Text('YAML')),
                    const PopupMenuItem(value: 'sql', child: Text('SQL')),
                    const PopupMenuItem(value: 'bash', child: Text('Bash')),
                  ],
                ),
              ],
            ),
          ),

          // Code Text Area
          TextField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            onChanged: (_) => _handleCodeChanged(),
            decoration: const InputDecoration(
              hintText: 'Enter your code here...',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
            maxLines: null,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
          ),
        ],
      ),
    );
  }
}
