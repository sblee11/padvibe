import 'dart:ui' show FontFeature;
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

  void _toggleDetachTimer(BuildContext context) {
    if (_timerOverlay == null) {
      _showTimerOverlay(context);
    } else {
      _removeTimerOverlay();
    }
  }

  void _showTimerOverlay(BuildContext context) {
    if (_timerOverlay != null) return;
    final overlay = Overlay.of(context, rootOverlay: true);
    if (overlay == null) return;

    _timerOverlay = OverlayEntry(
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return ValueListenableBuilder<Offset>(
          valueListenable: _timerOverlayPos,
          builder: (_, offset, __) {
            return Positioned(
              left: offset.dx,
              top: offset.dy,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Changed: clamp within screen while dragging (uses current overlay size)
                    final screen = MediaQuery.of(ctx).size;
                    final next = _timerOverlayPos.value + details.delta;
                    final sz = _timerOverlaySize.value;
                    _timerOverlayPos.value = Offset(
                      next.dx.clamp(8.0, screen.width - sz.width - 8.0),
                      next.dy.clamp(8.0, screen.height - sz.height - 8.0),
                    );
                  },
                  onPanEnd: (_) {
                    // Changed: snap to nearest horizontal edge (uses current overlay size)
                    final screen = MediaQuery.of(ctx).size;
                    final sz = _timerOverlaySize.value;
                    final x = _timerOverlayPos.value.dx;
                    final targetX = x < screen.width / 2
                        ? 8.0
                        : (screen.width - sz.width - 8.0);
                    _timerOverlayPos.value = Offset(
                      targetX,
                      _timerOverlayPos.value.dy.clamp(
                        8.0,
                        screen.height - sz.height - 8.0,
                      ),
                    );
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.move,
                    child: ValueListenableBuilder<Size>(
                      valueListenable: _timerOverlaySize,
                      builder: (_, sz, __) {
                        return SizedBox(
                          width: sz.width,
                          height: sz.height,
                          child: Obx(() {
                            // Changed: color-coded border, blinking indicator, better time format
                            final secs = Get.find<HomeController>()
                                .remainingSeconds
                                .value;
                            final accent = _urgencyColor(ctx, secs);
                            final blinking = _blink(secs);
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface
                                          .withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 12,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: accent.withOpacity(0.6),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.timer_outlined,
                                          color: accent,
                                        ),
                                        const SizedBox(width: 6),
                                        AnimatedOpacity(
                                          opacity: blinking ? 1 : 0.25,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            size: 8,
                                            color: accent,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Remaining: ${_formatRemaining(secs)}',
                                            overflow: TextOverflow.fade,
                                            softWrap: false,
                                            style: TextStyle(
                                              color: accent,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          tooltip: 'Stop all',
                                          icon: const Icon(Icons.stop),
                                          color: theme.colorScheme.error,
                                          onPressed: Get.find<HomeController>()
                                              .stopAll,
                                        ),
                                        IconButton(
                                          tooltip: 'Dock timer',
                                          icon: const Icon(
                                            Icons.close_fullscreen,
                                          ),
                                          onPressed: _removeTimerOverlay,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Added: bottom-right resize handle
                                Positioned(
                                  right: 4,
                                  bottom: 4,
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors
                                        .resizeUpLeftDownRight,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onPanUpdate: (details) {
                                        final screen = MediaQuery.of(ctx).size;
                                        final pos = _timerOverlayPos.value;
                                        final current = _timerOverlaySize.value;
                                        final newW =
                                            (current.width + details.delta.dx)
                                                .clamp(
                                                  _kOverlayMinW,
                                                  screen.width - pos.dx - 8.0,
                                                );
                                        final newH =
                                            (current.height + details.delta.dy)
                                                .clamp(
                                                  _kOverlayMinH,
                                                  screen.height - pos.dy - 8.0,
                                                );
                                        _timerOverlaySize.value = Size(
                                          newW,
                                          newH,
                                        );
                                      },
                                      onDoubleTap: () {
                                        // Optional: reset size to default
                                        _timerOverlaySize.value = const Size(
                                          _kOverlayW,
                                          _kOverlayH,
                                        );
                                      },
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .surfaceVariant
                                              .withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: accent.withOpacity(0.6),
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.open_in_full,
                                          size: 12,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(_timerOverlay!);
  }

  void _removeTimerOverlay() {
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
      body: Obx(() {
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
              final fileName = hasFile ? pad.path!.split('/').last : 'Empty';
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
      bottomNavigationBar: Obx(() {
        final secs = controller.remainingSeconds.value;
        final detached = _timerOverlay != null; // Added
        final accent = _urgencyColor(context, secs); // Added
        final blinking = _blink(secs); // Added
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
                // --- Changed: formatted, color-coded text and show time even when detached ---
                if (!detached)
                  Text(
                    'Remaining: ${_formatRemaining(secs)}',
                    style: TextStyle(
                      color: accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  Text(
                    'Timer detached (${_formatRemaining(secs)})',
                    style: TextStyle(
                      color: accent.withOpacity(0.85),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
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
