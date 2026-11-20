import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../strings/app_strings.dart';
import 'frame_bursts.dart';
import 'perf_monitor.dart';
import 'user_agent.dart';

/// Puts the frame-timing overlay above every page when `?perf` is on, and
/// returns [child] untouched (no recorder, no cost) otherwise.
class PerfGate extends ConsumerWidget {
  const PerfGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(perfModeProvider) ? PerfOverlay(child: child) : child;
}

/// A small semi-transparent panel over [child]: live frame rate, the last
/// bursts and the device. Only its buttons take taps.
class PerfOverlay extends StatefulWidget {
  const PerfOverlay({super.key, required this.child});

  final Widget child;

  /// How many bursts the panel lists (the copied text has them all).
  static const shown = 5;

  @override
  State<PerfOverlay> createState() => _PerfOverlayState();
}

class _PerfOverlayState extends State<PerfOverlay> {
  late final PerfMonitor _monitor = PerfMonitor()..addListener(_changed);
  bool _copied = false;

  void _changed() => setState(() => _copied = false);

  @override
  void dispose() {
    _monitor.dispose();
    super.dispose();
  }

  List<String> _burstLines(int n, BurstSummary b) => [
    AppStrings.perfBurstHead(n, b.durationMs / 1000, b.frames, b.averageFps),
    AppStrings.perfBurstGaps(b.p50Ms, b.p95Ms, b.maxMs, b.over17, b.over34),
    if (b.hasTimings)
      AppStrings.perfBurstEngine(
        b.buildP95Ms,
        b.buildMaxMs,
        b.rasterP95Ms,
        b.rasterMaxMs,
      ),
  ];

  List<String> _deviceLines(MediaQueryData media) => [
    AppStrings.perfDevice(
      media.devicePixelRatio,
      media.size.width,
      media.size.height,
    ),
    AppStrings.perfTimings(_monitor.timingsSeen),
    if (userAgent().isNotEmpty) userAgent(),
  ];

  Future<void> _copy(MediaQueryData media) async {
    _monitor.muteOwnTap();
    final bursts = _monitor.recorder.bursts;
    final text = [
      AppStrings.perfTitle,
      ..._deviceLines(media),
      for (var i = 0; i < bursts.length; i++)
        ..._burstLines(bursts.length - i, bursts[i]),
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final recorder = _monitor.recorder;
    final bursts = recorder.bursts;
    final lines = [
      AppStrings.perfLive(recorder.liveFps()),
      for (var i = 0; i < bursts.length && i < PerfOverlay.shown; i++)
        ..._burstLines(bursts.length - i, bursts[i]),
      if (bursts.isEmpty) AppStrings.perfEmpty,
      ..._deviceLines(media),
    ];
    const style = TextStyle(
      color: Colors.white,
      fontSize: 10.5,
      height: 1.3,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final panel = Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // The background and text let taps through to the page.
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xB3000000),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                IgnorePointer(
                  child: Text(
                    '${AppStrings.perfTitle}\n${lines.join('\n')}',
                    key: const Key('perf-overlay-text'),
                    style: style,
                  ),
                ),
                Row(
                  children: [
                    _PanelButton(
                      label: AppStrings.reset,
                      onPressed: _monitor.reset,
                    ),
                    const SizedBox(width: 8),
                    _PanelButton(
                      label: _copied
                          ? AppStrings.perfCopied
                          : AppStrings.perfCopy,
                      onPressed: () => _copy(media),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Stack(
      children: [
        widget.child,
        PositionedDirectional(
          top: media.padding.top + 4,
          start: 4,
          end: 4,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Its own layer, so its repaints never repaint the page.
              child: RepaintBoundary(child: panel),
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      minimumSize: const Size(64, 44),
      tapTargetSize: MaterialTapTargetSize.padded,
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
    child: Text(label),
  );
}
