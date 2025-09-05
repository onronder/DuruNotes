import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../main.dart';

/// Cached image widget for attachment display
/// Provides automatic caching, error handling, and analytics
class AttachmentImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showLoadingIndicator;

  const AttachmentImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showLoadingIndicator = true,
  });

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
            ? (context, url) => _buildPlaceholder()
            : null,
        errorWidget: (context, url, error) => _buildErrorWidget(error),
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

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height ?? 160,
      color: Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(dynamic error) {
    // Log cache miss / error for analytics
    logger.warn('Attachment image failed to load', data: {
      'url': url,
      'error': error.toString(),
    });
    
    analytics.event('attachment.cache_miss', properties: {
      'url_provided': url.isNotEmpty,
      'error_type': error.runtimeType.toString(),
    });

    return Container(
      width: width,
      height: height ?? 160,
      color: Colors.grey[100],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: TextStyle(
              color: Colors.grey[600],
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
  final String url;
  final double size;

  const AttachmentThumbnail({
    super.key,
    required this.url,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return AttachmentImage(
      url: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(6),
      showLoadingIndicator: false, // Don't show loading in thumbnails
    );
  }
}

/// Full-size attachment viewer with caching
class AttachmentViewer extends StatelessWidget {
  final String url;
  final String? title;

  const AttachmentViewer({
    super.key,
    required this.url,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'Attachment'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 3.0,
          child: AttachmentImage(
            url: url,
            fit: BoxFit.contain,
          ),
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
    logger.info('Attachment image cache cleared');
    analytics.event('attachment.cache_cleared');
  }

  /// Get cache size information
  static Future<int> getCacheSize() async {
    // This would require additional implementation
    // CachedNetworkImage doesn't provide direct cache size access
    return 0;
  }
}
