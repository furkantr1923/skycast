import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../core/failure.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? const Color(0x1A0B1424),
        borderRadius: BorderRadius.circular(Sky.radius),
        border: Border.all(color: Sky.stroke),
        gradient: color == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
              )
            : null,
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(borderRadius: BorderRadius.circular(Sky.radius), onTap: onTap, child: content),
            ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.icon});

  final String text;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 16, color: Sky.textDim), const SizedBox(width: 6)],
            Expanded(child: Text(text.toUpperCase(), style: Sky.section)),
            ?trailing,
          ],
        ),
      );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Veriler alınıyor…'});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2.6)),
            const SizedBox(height: 16),
            Text(label, style: Sky.small),
          ],
        ),
      );
}

/// Hata durumu: neyin kullanılamadığını ve neden olduğunu Türkçe söyler.
class FailureView extends StatelessWidget {
  const FailureView({super.key, required this.failure, this.onRetry, this.feature, this.compact = false});

  final AppFailure failure;
  final VoidCallback? onRetry;
  final String? feature;
  final bool compact;

  IconData get _icon => switch (failure.kind) {
        FailureKind.offline => Icons.wifi_off_rounded,
        FailureKind.timeout => Icons.hourglass_bottom_rounded,
        FailureKind.rateLimited => Icons.speed_rounded,
        FailureKind.permissionDenied || FailureKind.locationDisabled => Icons.location_off_rounded,
        FailureKind.notSupported => Icons.public_off_rounded,
        _ => Icons.cloud_off_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, color: Sky.warm, size: compact ? 20 : 26),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                feature == null ? failure.title : '$feature kullanılamıyor',
                style: TextStyle(fontSize: compact ? 15 : 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          feature == null ? failure.message : '${failure.title}. ${failure.message}',
          style: Sky.small,
          textAlign: compact ? TextAlign.start : TextAlign.center,
        ),
        if (failure.source != null) ...[
          const SizedBox(height: 6),
          Text('Kaynak: ${failure.source}', style: Sky.tiny),
        ],
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          FilledButton.tonalIcon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Yeniden dene')),
        ],
      ],
    );
    if (compact) return GlassCard(child: body);
    return Center(child: Padding(padding: const EdgeInsets.all(28), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: body)));
  }
}

/// Atıf/kaynak satırı (lisans gereği görünür olmalı).
class SourceNote extends StatelessWidget {
  const SourceNote(this.text, {super.key, this.url, this.align = TextAlign.center});

  final String text;
  final String? url;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final t = Text(text, style: Sky.tiny, textAlign: align);
    if (url == null) return t;
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: t),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = Sky.accent, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
            Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

/// Pusula biçiminde rüzgâr yönü oku. [degrees] rüzgârın geldiği yöndür.
class WindArrow extends StatelessWidget {
  const WindArrow({super.key, required this.degrees, this.size = 18, this.color = Sky.accent});

  final double? degrees;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (degrees == null) return SizedBox(width: size, height: size);
    // Ok rüzgârın gittiği yönü gösterir (geldiği yön + 180°).
    return Transform.rotate(
      angle: (degrees! + 180) * 3.141592653589793 / 180,
      child: Icon(Icons.navigation_rounded, size: size, color: color),
    );
  }
}
