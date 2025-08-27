// Import Service Usage Demo
// This file demonstrates how to use the ImportService

import 'package:duru_notes_app/core/parser/note_block_parser.dart';

/// Demo showing import service usage
void main() async {
  print('🔄 Import Service Demo');
  print('=====================\n');

  // Demo 1: Parse Markdown Content
  await _demoMarkdownParsing();
  
  // Demo 2: File Type Detection
  await _demoFileTypeDetection();
  
  // Demo 3: Sample Import Flow
  await _demoImportFlow();
  
  print('\n✅ Demo completed!');
}

/// Demonstrate markdown parsing capabilities
Future<void> _demoMarkdownParsing() async {
  print('📝 Markdown Parsing Demo');
  print('-' * 25);
  
  const sampleMarkdown = '''# Welcome to Duru Notes

This is your **encrypted**, mobile-first note-taking app.

## Features

- 🔒 End-to-end encryption
- 📱 Mobile-optimized interface
- 🔍 Full-text search
- 📎 File attachments

## Todo List

- [x] Set up authentication
- [x] Implement encryption
- [ ] Add voice notes
- [ ] OCR scanning

## Code Example

```dart
print('Hello, Duru Notes!');
```

> Remember: Your privacy is our priority.''';

  final parser = NoteBlockParser();
  final blocks = parser.parseMarkdownToBlocks(sampleMarkdown);
  
  print('Parsed ${blocks.length} blocks:');
  for (int i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    print('  ${i + 1}. ${block.type.name}: "${block.content.length > 50 ? '${block.content.substring(0, 50)}...' : block.content}"');
    if (block.properties.isNotEmpty) {
      print('     Properties: ${block.properties}');
    }
  }
  print('');
}

/// Demonstrate file type detection
Future<void> _demoFileTypeDetection() async {
  print('🔍 File Type Detection Demo');
  print('-' * 28);
  
  final testFiles = [
    'my-notes.md',
    'evernote-export.enex',
    'document.txt',
    'README.MD',
    'notes.ENEX',
  ];
  
  for (final filename in testFiles) {
    final extension = filename.split('.').last.toLowerCase();
    String type;
    bool supported;
    
    switch (extension) {
      case 'md':
        type = 'Markdown';
        supported = true;
        break;
      case 'enex':
        type = 'Evernote Export';
        supported = true;
        break;
      default:
        type = 'Unknown';
        supported = false;
    }
    
    final status = supported ? '✅' : '❌';
    print('  $status $filename → $type ${supported ? '(Supported)' : '(Not supported)'}');
  }
  print('');
}

/// Demonstrate import workflow
Future<void> _demoImportFlow() async {
  print('⚡ Import Flow Demo');
  print('-' * 18);
  
  print('Import workflow steps:');
  print('  1. 📁 User selects file/folder');
  print('  2. 🔍 Service detects file type');
  print('  3. 📖 Content is parsed');
  print('  4. 🧱 Converted to blocks');
  print('  5. 💾 Saved to database');
  print('  6. 🔍 Indexed for search');
  print('  7. 📊 Analytics recorded');
  print('');
  
  print('Supported import formats:');
  print('  • Markdown (.md) - Single files');
  print('  • Evernote Export (.enex) - Batch import');
  print('  • Obsidian Vaults - Directory import');
  print('');
  
  print('Progress tracking:');
  print('  • Real-time progress updates');
  print('  • Current file being processed');
  print('  • Success/error counts');
  print('  • Total time elapsed');
  print('');
  
  print('Error handling:');
  print('  • Graceful failure handling');
  print('  • Detailed error messages');
  print('  • Partial import success');
  print('  • Analytics error tracking');
}
