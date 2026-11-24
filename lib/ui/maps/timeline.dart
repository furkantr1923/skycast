import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Kare animasyonu denetimi: oynat/duraklat, ileri/geri, zaman çizelgesi.
class FrameTimeline extends StatefulWidget {
  const FrameTimeline({
    super.key,
    required this.count,
    required this.index,
    required this.onChanged,
    required this.labelFor,
    required this.frameMs,
    this.subtitle,
    this.tagFor,
  });

  final int count;
  final int index;
  final ValueChanged<int> onChanged;
  final String Function(int) labelFor;
  final String? Function(int)? tagFor;
  final int frameMs;
  final String? subtitle;

  @override
  State<FrameTimeline> createState() => _FrameTimelineState();
}

class _FrameTimelineState extends State<FrameTimeline> {
  Timer? _timer;
  bool get _playing => _timer != null;

  void _toggle() {
    if (_playing) {
      _timer?.cancel();
      setState(() => _timer = null);
      return;
    }
    setState(() {
      _timer = Timer.periodic(Duration(milliseconds: widget.frameMs), (_) {
        final next = widget.index + 1;
        // Son karede kısa bir duraklama etkisi için başa dön.
        widget.onChanged(next >= widget.count ? 0 : next);
      });
    });
  }

  @override
  void didUpdateWidget(covariant FrameTimeline old) {
    super.didUpdateWidget(old);
    if (old.frameMs != widget.frameMs && _playing) {
      _timer?.cancel();
      _timer = null;
      _toggle();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tagFor?.call(widget.index);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xF00B1324),
        borderRadius: BorderRadius.circular(Sky.radius),
        border: Border.all(color: Sky.stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton.filled(
                tooltip: _playing ? 'Duraklat' : 'Oynat',
                onPressed: widget.count < 2 ? null : _toggle,
                icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              IconButton(
                tooltip: 'Önceki kare',
                onPressed: widget.index > 0 ? () => widget.onChanged(widget.index - 1) : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              IconButton(
                tooltip: 'Sonraki kare',
                onPressed: widget.index < widget.count - 1 ? () => widget.onChanged(widget.index + 1) : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(widget.labelFor(widget.index), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      if (tag != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: Sky.accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
                          child: Text(tag, style: const TextStyle(fontSize: 11, color: Sky.accent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    if (widget.subtitle != null) Text(widget.subtitle!, style: Sky.tiny, maxLines: 2),
                  ],
                ),
              ),
              Text('${widget.index + 1}/${widget.count}', style: Sky.small),
            ],
          ),
          if (widget.count > 1)
            Slider(
              value: widget.index.toDouble(),
              min: 0,
              max: (widget.count - 1).toDouble(),
              divisions: widget.count - 1,
              onChanged: (v) => widget.onChanged(v.round()),
            ),
        ],
      ),
    );
  }
}
