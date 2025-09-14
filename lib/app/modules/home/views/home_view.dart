import 'dart:ui' show FontFeature;
import 'dart:math' as math;
import 'dart:async'; // added
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import 'package:pads/app/data/pad_model.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  // --- Added: detachable timer overlay state/helpers ---
  static OverlayEntry? _timerOverlay;
  static final ValueNotifier<Offset> _timerOverlayPos = ValueNotifier<Offset>(
    const Offset(80, 80),
  );

  // Added: overlay sizing (now resizable)
  static const double _kOverlayW = 260.0;
  static const double _kOverlayH = 56.0;
  static const double _kOverlayMinW = 200.0;
  static const double _kOverlayMinH = 56.0;
  static final ValueNotifier<Size> _timerOverlaySize = ValueNotifier<Size>(
    const Size(_kOverlayW, _kOverlayH),
  );

  // Added: API to get formatted timer text only
  static String getTimerTextOnly() {
    final secs = Get.find<HomeController>().remainingSeconds.value;
    return _formatRemaining(secs);
  }

  // Changed: make formatter static so it can be used by the API
  static String _formatRemaining(double secs) {
    if (secs.isNaN || secs.isInfinite) return '--:--';
    if (secs < 0) secs = 0;
    final totalMs = (secs * 1000).round();
    final hours = totalMs ~/ 3600000;
    final mins = (totalMs % 3600000) ~/ 60000;
    final secInt = (totalMs % 60000) ~/ 1000;
    final tenths = ((totalMs % 1000) ~/ 100);
    String two(int n) => n.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:${two(mins)}:${two(secInt)}.$tenths';
    }
    return '${two(mins)}:${two(secInt)}.$tenths';
  }

  // Added: urgency color for timer
  Color _urgencyColor(BuildContext context, double secs) {
    if (secs <= 10) return Colors.redAccent;
    if (secs <= 30) return Colors.orangeAccent;
    return Theme.of(context).colorScheme.primary;
  }

  // Added: blink indicator in last 5s
  bool _blink(double secs) {
    if (secs > 5) return false;
    final t = DateTime.now().millisecondsSinceEpoch ~/ 400; // ~2.5Hz blink
    return t.isEven;
  }

  // --- End added ---

  // --- Added: overlay controls (toggle/show/hide) ---
  void _toggleTimerOverlay(BuildContext context) {
    if (_timerOverlay == null) {
      _showTimerOverlay(context);
    } else {
      _hideTimerOverlay();
    }
  }

  void _showTimerOverlay(BuildContext context) {
    if (_timerOverlay != null) return;
    final overlay = Overlay.of(context);

    _timerOverlay = OverlayEntry(
      builder: (ctx) {
        return ValueListenableBuilder<Offset>(
          valueListenable: _timerOverlayPos,
          builder: (_, pos, __) {
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: ValueListenableBuilder<Size>(
                valueListenable: _timerOverlaySize,
                builder: (_, size, __) {
                  return Material(
                    color: Colors.transparent,
                    child: GestureDetector(
                      // Drag the whole card by clicking and dragging anywhere except the resize handle.
                      onPanUpdate: (details) {
                        _timerOverlayPos.value =
                            _timerOverlayPos.value + details.delta;
                      },
                      child: Container(
                        width: size.width,
                        height: size.height,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            ctx,
                          ).colorScheme.surface.withOpacity(0.98),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(
                              ctx,
                            ).colorScheme.primary.withOpacity(0.35),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Center: big, readable timer text
                            Center(
                              child: Obx(() {
                                final secs = Get.find<HomeController>()
                                    .remainingSeconds
                                    .value;
                                final accent = _urgencyColor(ctx, secs);
                                final blinking = _blink(secs);
                                final text = _formatRemaining(secs);
                                final h = _timerOverlaySize.value.height;
                                final fontSize = (h * 0.55).clamp(28.0, 220.0);

                                return AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 120),
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w700,
                                    color: accent.withOpacity(
                                      blinking ? 1.0 : 0.45,
                                    ),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  child: Text(text),
                                );
                              }),
                            ),
                            // Top-right: close button
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton(
                                tooltip: 'Pin timer',
                                padding: const EdgeInsets.all(6),
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                onPressed: _hideTimerOverlay,
                                icon: const Icon(Icons.close),
                              ),
                            ),
                            // Bottom-right: resize handle
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onPanUpdate: (details) {
                                  final w = math.max(
                                    _kOverlayMinW,
                                    _timerOverlaySize.value.width +
                                        details.delta.dx,
                                  );
                                  final h = math.max(
                                    _kOverlayMinH,
                                    _timerOverlaySize.value.height +
                                        details.delta.dy,
                                  );
                                  _timerOverlaySize.value = Size(w, h);
                                },
                                child: MouseRegion(
                                  cursor:
                                      SystemMouseCursors.resizeUpLeftDownRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.open_in_full,
                                      size: 16,
                                      color: Theme.of(
                                        ctx,
                                      ).colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );

    overlay.insert(_timerOverlay!);
  }

  void _hideTimerOverlay() {
    _timerOverlay?.remove();
    _timerOverlay = null;
  }
  // --- End added ---

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.red,
      Colors.indigo,
      Colors.cyan,
      Colors.amber,
      Colors.pink,
      Colors.lime,
      Colors.brown,
    ];
    return Scaffold(
      appBar: _appBar(context),
      body: Row(
        children: [
          Expanded(
            child: Obx(() {
              // Read the ticker to trigger rebuilds for progress bars.
              final _ = controller.remainingSeconds.value;
              return Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  itemCount: controller.pads.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 2, // wider than tall -> less height
                  ),
                  itemBuilder: (context, index) {
                    final pad = controller.pads[index];
                    final color = colors[index % colors.length];
                    final hasFile = pad.path != null;
                    final fileName = hasFile
                        ? pad.path!.split('/').last
                        : 'Empty';
                    return DropTarget(
                      onDragDone: (detail) {
                        if (detail.files.isEmpty) return;
                        final f = detail.files.first;
                        if (!f.name.toLowerCase().endsWith('.mp3') &&
                            !f.name.toLowerCase().endsWith('.wav') &&
                            !f.name.toLowerCase().endsWith('.ogg') &&
                            !f.name.toLowerCase().endsWith('.flac') &&
                            !f.name.toLowerCase().endsWith('.aac') &&
                            !f.name.toLowerCase().endsWith('.m4a')) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Unsupported file type: ${f.name}'),
                            ),
                          );
                          return;
                        }
                        controller.assignFilePathToPad(index, f.path);
                      },
                      child: _pad(color, hasFile, index, pad, fileName),
                    );
                  },
                ),
              );
            }),
          ),
          // master audio meter <-- new
          const SizedBox(width: 8),
          _MasterAudioMeter(controller: controller),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: Obx(() {
        final secs = controller.remainingSeconds.value;
        final detached = _timerOverlay != null;
        final accent = _urgencyColor(context, secs);
        final blinking = _blink(secs);
        return BottomAppBar(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: accent),
                const SizedBox(width: 6),
                AnimatedOpacity(
                  opacity: blinking ? 1 : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.circle, size: 8, color: accent),
                ),
                const SizedBox(width: 8),
                // --- Changed: bigger, more readable timer text; add pop-out/pin button ---
                if (!detached)
                  Text(
                    'Remaining: ${_formatRemaining(secs)}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  Text(
                    'Timer detached (${_formatRemaining(secs)})',
                    style: TextStyle(
                      color: accent.withOpacity(0.85),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: detached ? 'Pin timer' : 'Pop-out timer',
                  icon: Icon(detached ? Icons.push_pin : Icons.open_in_new),
                  onPressed: () => _toggleTimerOverlay(context),
                ),
                // --- End changed ---
                const Spacer(),
                TextButton.icon(
                  onPressed: controller.stopAll,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop All'),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  AppBar _appBar(BuildContext context) {
    return AppBar(
      title: const Text('Jingle Pads'),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'Add files',
          icon: const Icon(Icons.library_music),
          onPressed: controller.addFiles,
        ),
        IconButton(
          tooltip: 'Stop all',
          icon: const Icon(Icons.stop_circle_outlined),
          onPressed: controller.stopAll,
        ),
        IconButton(
          tooltip: 'Clear all',
          icon: const Icon(Icons.delete_sweep_outlined),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Clear all pads?'),
                content: const Text(
                  'This stops playback, removes assigned files, and clears saved layout.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            );
            if (ok == true) {
              await controller.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All pads cleared')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Material _pad(
    Color color,
    bool hasFile,
    int index,
    Pad pad,
    String fileName,
  ) {
    final progress = hasFile
        ? controller.audioService.getRemainingFractionForPath(pad.path!)
        : null;
    final isPlaying = hasFile && controller.audioService.isPlaying(pad.path!);

    // Blend base color towards white when playing for a clear visual change.
    final baseColor = color.withOpacity(hasFile ? 0.9 : 0.5);
    final playingColor = Color.fromARGB(255, 3, 165, 0); // Light Blue 300
    final bgColor = isPlaying ? playingColor.withOpacity(0.95) : baseColor;

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasFile ? () => controller.playPad(index) : null,
        onLongPress: () => controller.assignFileToPad(index),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasFile ? Icons.music_note : Icons.add,
                color: Colors.white,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                pad.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              if (progress != null) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress, // 1.0 -> 0.0 while playing
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    color: Colors.white,
                  ),
                ),
              ] else if (!hasFile) ...[
                const Text(
                  'Long-press to assign',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// A lightweight master-level meter that attempts to read levels from audioService.
// Falls back to a subtle animated approximation when any pad is playing.
class _MasterAudioMeter extends StatefulWidget {
  final HomeController controller;
  const _MasterAudioMeter({required this.controller});

  @override
  State<_MasterAudioMeter> createState() => _MasterAudioMeterState();
}

class _MasterAudioMeterState extends State<_MasterAudioMeter> {
  Timer? _timer;
  double _levelL = 0.0, _levelR = 0.0;
  double _peakL = 0.0, _peakR = 0.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    final levels = _readLevels();
    final newL = levels.$1.clamp(0.0, 1.0);
    final newR = levels.$2.clamp(0.0, 1.0);

    // Attack fast, decay slow
    const decay = 0.85;
    final nextL = newL > _levelL ? newL : _levelL * decay;
    final nextR = newR > _levelR ? newR : _levelR * decay;

    // Peak-hold decay
    final nextPeakL = math.max(newL, _peakL - 0.02);
    final nextPeakR = math.max(newR, _peakR - 0.02);

    if (!mounted) return;
    setState(() {
      _levelL = nextL;
      _levelR = nextR;
      _peakL = nextPeakL;
      _peakR = nextPeakR;
    });
  }

  // Try a few common shapes that an audio service might expose.
  (double, double) _readLevels() {
    final svc = widget.controller.audioService as dynamic;
    double l = 0.0, r = 0.0;

    // Try getMasterLevels(): [l, r] or {left/right}
    try {
      final fn = (svc.getMasterLevels as Function);
      final res = fn();
      if (res is List && res.isNotEmpty) {
        l = _numToDouble(res[0]);
        r = _numToDouble(res.length > 1 ? res[1] : res[0]);
        return (l, r);
      } else if (res is Map) {
        l = _numToDouble(res['left'] ?? res['l'] ?? res['L']);
        r = _numToDouble(res['right'] ?? res['r'] ?? res['R'] ?? l);
        return (l, r);
      }
    } catch (_) {
      // ignore
    }

    // Try fields masterRmsL/masterRmsR or masterPeakL/masterPeakR
    try {
      l = _numToDouble(svc.masterRmsL ?? svc.masterPeakL ?? svc.masterLevel);
      r = _numToDouble(
        svc.masterRmsR ?? svc.masterPeakR ?? svc.masterLevel ?? l,
      );
      if (l > 0 || r > 0) return (l, r);
    } catch (_) {
      // ignore
    }

    // Try getMasterLevel(): mono
    try {
      final fn = (svc.getMasterLevel as Function);
      final m = _numToDouble(fn());
      if (m > 0) return (m, m);
    } catch (_) {
      // ignore
    }

    // Fallback: If anything is playing, show a subtle animated approximation.
    final anyPlaying = _anyPadPlaying();
    if (!anyPlaying) return (0.0, 0.0);

    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final approxL = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(t * 7.0));
    final approxR = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(t * 8.2 + 1.3));
    return (approxL, approxR);
  }

  bool _anyPadPlaying() {
    try {
      for (final Pad p in widget.controller.pads) {
        final path = p.path;
        if (path != null && widget.controller.audioService.isPlaying(path)) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  double _numToDouble(dynamic v) => v is num ? v.toDouble() : 0.0;

  Color _meterColor(double x, ColorScheme scheme) {
    if (x < 0.7) return Colors.greenAccent.shade400;
    if (x < 0.9) return Colors.orangeAccent.shade400;
    return Colors.redAccent.shade400;
  }

  Widget _buildBar(double level, double peak, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (_, c) {
        final h = c.maxHeight;
        final w = c.maxWidth;
        final fillH = h * level.clamp(0.0, 1.0);
        final peakY = h * (1.0 - peak.clamp(0.0, 1.0));

        return Stack(
          children: [
            // Track
            Container(
              width: w,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: scheme.outlineVariant.withOpacity(0.6),
                  width: 1,
                ),
              ),
            ),
            // Fill
            Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 40),
                width: w,
                height: fillH,
                decoration: BoxDecoration(
                  color: _meterColor(level, scheme),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(6),
                  ),
                ),
              ),
            ),
            // Peak hold line
            Positioned(
              left: 0,
              right: 0,
              top: peakY - 1,
              height: 2,
              child: Container(color: scheme.onSurface.withOpacity(0.8)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surface.withOpacity(0.9),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Master',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildBar(_levelL, _peakL, scheme)),
                const SizedBox(width: 6),
                Expanded(child: _buildBar(_levelR, _peakR, scheme)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'L',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
              ),
              Text(
                'R',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.7)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
