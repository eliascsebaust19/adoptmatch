import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/storage_service.dart';

class AppNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth = 600,
    this.memCacheHeight = 600,
  });

  /// Injects bearer token for private Vercel Blob store URLs
  static Map<String, String>? getHeadersForUrl(String url) {
    if (url.contains('blob.vercel-storage.com') && StorageService.vercelBlobToken.isNotEmpty) {
      return {
        'Authorization': 'Bearer ${StorageService.vercelBlobToken}',
      };
    }
    return null;
  }

  /// Convenience image provider for CircleAvatar and decoration images
  static ImageProvider provider(
    String url, {
    int? memCacheWidth = 600,
    int? memCacheHeight = 600,
  }) {
    if (url.startsWith('data:image')) {
      final commaIdx = url.indexOf(',');
      final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
      return MemoryImage(base64Decode(base64Str));
    }
    return CachedNetworkImageProvider(
      url,
      headers: getHeadersForUrl(url),
      maxWidth: memCacheWidth,
      maxHeight: memCacheHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.pets, size: 20, color: Color(0xFF0D9488)),
      ),
    );

    final defaultError = Container(
      color: const Color(0xFFE2E8F0),
      child: const Icon(Icons.pets, size: 36, color: Colors.grey),
    );

    if (imageUrl.isEmpty) {
      return errorWidget ?? defaultError;
    }

    if (imageUrl.startsWith('data:image')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? imageUrl.substring(commaIdx + 1) : imageUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => errorWidget ?? defaultError,
        );
      } catch (_) {
        return errorWidget ?? defaultError;
      }
    }

    if (kIsWeb) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        headers: getHeadersForUrl(imageUrl),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ?? defaultPlaceholder;
        },
        errorBuilder: (context, error, stackTrace) {
          return errorWidget ?? defaultError;
        },
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: getHeadersForUrl(imageUrl),
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      maxWidthDiskCache: 1200,
      maxHeightDiskCache: 1200,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 150),
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultError,
    );
  }
}
