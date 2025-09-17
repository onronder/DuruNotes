import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailAttachmentRef {
  const EmailAttachmentRef({
    required this.path,
    required this.filename,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String path; // "<user_id>/<folder>/file.ext"
  final String filename; // "file.ext"
  final String mimeType; // "image/png", "application/pdf", ...
  final int sizeBytes;
}

class EmailAttachmentsSection extends StatefulWidget {
  const EmailAttachmentsSection({
    required this.files,
    super.key,
    this.bucketId = 'inbound-attachments',
    this.signedUrlTtlSeconds = 60,
  });

  final List<EmailAttachmentRef> files;
  final String bucketId;
  final int signedUrlTtlSeconds;

  @override
  State<EmailAttachmentsSection> createState() =>
      _EmailAttachmentsSectionState();
}

class _EmailAttachmentsSectionState extends State<EmailAttachmentsSection> {
  final _cache = <String, _SignedUrlCache>{}; // path -> signed url cache

  @override
  Widget build(BuildContext context) {
    if (widget.files.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, widget.files.length),
            const SizedBox(height: 6),
            ...widget.files.map(_buildItem),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, int count) {
    return Row(
      children: [
        const Icon(Icons.attachment, size: 18),
        const SizedBox(width: 8),
        Text(
          'Attachments ($count)',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildItem(EmailAttachmentRef f) {
    final sizeText = _humanSize(f.sizeBytes);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(_iconForMime(f.mimeType), size: 22),
      title: Text(f.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$sizeText • ${f.mimeType}'),
      trailing: TextButton(
        onPressed: () => _openAttachment(f),
        child: const Text('Open'),
      ),
      onTap: () => _openAttachment(f),
    );
  }

  Future<void> _openAttachment(EmailAttachmentRef f) async {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cached = _cache[f.path];
      if (cached != null && cached.expiresAtMs > nowMs) {
        await _launch(cached.url);
        return;
      }

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening attachment...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final storage = Supabase.instance.client.storage.from(widget.bucketId);
      final signed = await storage.createSignedUrl(
        f.path,
        widget.signedUrlTtlSeconds,
      );

      _cache[f.path] = _SignedUrlCache(
        url: signed,
        expiresAtMs: DateTime.now()
            .add(Duration(seconds: widget.signedUrlTtlSeconds - 5))
            .millisecondsSinceEpoch,
      );

      debugPrint('[attachments] open ${f.filename} (${f.mimeType})');
      await _launch(signed);
    } catch (e) {
      debugPrint('[attachments] open failed for ${f.path}: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open attachment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('launchUrl failed');
    }
  }

  static String _humanSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  static IconData _iconForMime(String mime) {
    final m = mime.toLowerCase();
    if (m.startsWith('image/')) return Icons.image_outlined;
    if (m == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (m.startsWith('audio/')) return Icons.audiotrack_outlined;
    if (m.startsWith('video/')) return Icons.videocam_outlined;
    if (m.contains('zip') || m.contains('compressed'))
      return Icons.archive_outlined;
    if (m.contains('excel') || m.contains('spreadsheet') || m.contains('xls'))
      return Icons.table_chart_outlined;
    if (m.contains('word') || m.contains('document') || m.contains('doc'))
      return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _SignedUrlCache {
  _SignedUrlCache({required this.url, required this.expiresAtMs});
  final String url;
  final int expiresAtMs;
}
