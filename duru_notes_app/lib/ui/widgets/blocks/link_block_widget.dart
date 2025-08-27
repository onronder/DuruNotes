import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/note_block.dart';

class LinkBlockWidget extends StatefulWidget {
  const LinkBlockWidget({
    super.key,
    required this.block,
    required this.isFocused,
    required this.onChanged,
    required this.onFocusChanged,
  });

  final NoteBlock block;
  final bool isFocused;
  final Function(NoteBlock) onChanged;
  final Function(bool) onFocusChanged;

  @override
  State<LinkBlockWidget> createState() => _LinkBlockWidgetState();
}

class _LinkBlockWidgetState extends State<LinkBlockWidget> {
  late TextEditingController _titleController;
  late TextEditingController _urlController;
  late FocusNode _titleFocusNode;
  late FocusNode _urlFocusNode;
  late String _title;
  late String _url;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _parseLinkData();
    _titleController = TextEditingController(text: _title);
    _urlController = TextEditingController(text: _url);
    _titleFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
    
    _titleFocusNode.addListener(() {
      widget.onFocusChanged(_titleFocusNode.hasFocus);
    });

    if (widget.isFocused) {
      _isEditing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(LinkBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.block.data != oldWidget.block.data) {
      _parseLinkData();
      _titleController.text = _title;
      _urlController.text = _url;
    }
    
    if (widget.isFocused && !oldWidget.isFocused) {
      _isEditing = true;
      _titleFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _titleFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _parseLinkData() {
    // Format: "title|url"
    final parts = widget.block.data.split('|');
    if (parts.length >= 2) {
      _title = parts[0];
      _url = parts[1];
    } else {
      _title = widget.block.data.isNotEmpty ? widget.block.data : 'Link Title';
      _url = '';
    }
  }

  void _updateLink() {
    final linkData = '${_titleController.text}|${_urlController.text}';
    final newBlock = widget.block.copyWith(data: linkData);
    widget.onChanged(newBlock);
  }

  void _handleTitleChanged() {
    _title = _titleController.text;
    _updateLink();
  }

  void _handleUrlChanged() {
    _url = _urlController.text;
    _updateLink();
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
    
    if (_isEditing) {
      _titleFocusNode.requestFocus();
    }
  }

  Future<void> _openLink() async {
    if (_url.isNotEmpty) {
      final uri = Uri.tryParse(_url);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return _buildEditingView();
    } else {
      return _buildDisplayView();
    }
  }

  Widget _buildEditingView() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.blue.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                'Link',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.check, size: 16),
                onPressed: _toggleEditing,
                tooltip: 'Save',
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Title Field
          TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            onChanged: (_) => _handleTitleChanged(),
            decoration: const InputDecoration(
              labelText: 'Link Title',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // URL Field
          TextField(
            controller: _urlController,
            focusNode: _urlFocusNode,
            onChanged: (_) => _handleUrlChanged(),
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              hintText: 'https://example.com',
            ),
            keyboardType: TextInputType.url,
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayView() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: _openLink,
        onLongPress: _toggleEditing,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.link,
                size: 20,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title.isNotEmpty ? _title : 'Untitled Link',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    if (_url.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _url,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    onPressed: _openLink,
                    tooltip: 'Open link',
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16),
                    onPressed: _toggleEditing,
                    tooltip: 'Edit link',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
