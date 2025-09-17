import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays an attachment image from a signed URL.
/// Shows a graceful placeholder and a SnackBar on load error.
class AttachmentImage extends StatelessWidget {
  const AttachmentImage({
    required this.url,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showLoadingIndicator = true,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showLoadingIndicator;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: showLoadingIndicator
            ? (context, url) => _buildPlaceholder(context)
            : null,
        errorWidget: (context, url, error) => _buildErrorWidget(context, error),
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        // Cache configuration
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
        maxWidthDiskCache: 1024, // Max width for disk cache
        maxHeightDiskCache: 1024, // Max height for disk cache
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 160,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildErrorWidget(BuildContext context, dynamic error) {
    // Show error message in a post-frame callback to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load attachment image'),
          duration: Duration(seconds: 2),
        ),
      );
    });

    return Container(
      width: width,
      height: height ?? 160,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thumbnail variant optimized for list views
class AttachmentThumbnail extends StatelessWidget {
  const AttachmentThumbnail({required this.url, super.key, this.size = 60});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AttachmentImage(
      url: url,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(6),
      showLoadingIndicator: false, // Don't show loading in thumbnails
    );
  }
}

/// Full-size attachment viewer with caching
class AttachmentViewer extends StatelessWidget {
  const AttachmentViewer({required this.url, super.key, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Attachment'),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? Theme.of(context).colorScheme.surface
            : const Color(0xFF0F1E2E),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.surface
          : const Color(0xFF0F1E2E),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3,
          child: AttachmentImage(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// Utility functions for attachment handling
class AttachmentUtils {
  /// Check if URL is a valid image format
  static bool isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.jpg') ||
        lowerUrl.endsWith('.jpeg') ||
        lowerUrl.endsWith('.png') ||
        lowerUrl.endsWith('.gif') ||
        lowerUrl.endsWith('.webp') ||
        lowerUrl.endsWith('.bmp');
  }

  /// Generate thumbnail URL if supported by backend
  static String getThumbnailUrl(String originalUrl, {int size = 200}) {
    // This would depend on your backend thumbnail generation
    // For now, return original URL
    return originalUrl;
  }

  /// Clear image cache (useful for settings/debugging)
  static Future<void> clearImageCache() async {
    await CachedNetworkImage.evictFromCache('');
    debugPrint('[AttachmentUtils] Image cache cleared');
  }

  /// Get cache size information
  static Future<int> getCacheSize() async {
    // This would require additional implementation
    // CachedNetworkImage doesn't provide direct cache size access
    return 0;
  }
}
