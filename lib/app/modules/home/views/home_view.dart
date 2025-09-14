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
