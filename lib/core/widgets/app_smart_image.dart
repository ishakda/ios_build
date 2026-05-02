import 'package:flutter/material.dart';
import 'package:untitled1/core/theme/app_colors.dart';
import 'package:untitled1/core/theme/app_icons.dart';

class AppSmartImage extends StatelessWidget {
  const AppSmartImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.low,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) {
          return child;
        }
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: frame == null ? 0 : 1,
          child: child,
        );
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Container(
          width: width,
          height: height,
          color: AppColors.greyLight,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) => Container(
        width: width,
        height: height,
        color: AppColors.greyLight,
        alignment: Alignment.center,
        child: const Icon(AppIcons.imageBroken),
      ),
    );

    if (borderRadius == null) {
      return image;
    }
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
