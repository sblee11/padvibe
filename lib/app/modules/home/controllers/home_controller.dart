import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:pads/app/data/pad_model.dart';
import 'package:pads/app/service/audio_player_service.dart';
import 'package:pads/app/service/storage_service.dart';
import 'package:pads/main.dart';

class HomeController extends GetxController {
  final audioService = Get.find<AudioPlayerService>();
  final storage = Get.put(StorageService(), permanent: true);

  final count = 0.obs;
  final pads = <Pad>[for (int i = 1; i <= 20; i++) Pad(name: 'Pad $i')].obs;

  final remainingSeconds = 0.0.obs;
  Timer? _ticker;

  // Track the created timer window id to push updates
  int? _timerWindowId;

  @override
  void onInit() {
    super.onInit();
    // Load persisted pads (fills up to 20 if fewer are stored)
    () async {
      await storage.init();
      final loaded = await storage.loadPads(ensureCount: pads.length);
      if (loaded.isNotEmpty) {
        pads.assignAll(loaded);
      }

      // Sanitize missing files and migrate external files into app library.
      bool changed = false;
      for (var i = 0; i < pads.length; i++) {
        final p = pads[i].path;
        if (p == null) continue;
        final exists = kIsWeb ? true : File(p).existsSync();
        if (!exists) {
          pads[i] = pads[i].copyWith(path: null);
          changed = true;
          continue;
        }
        if (!kIsWeb) {
          final inLib = await storage.isInAudioLibrary(p);
          if (!inLib) {
            try {
              final dst = await storage.importAudioFile(p);
              pads[i] = pads[i].copyWith(path: dst);
              changed = true;
            } catch (_) {
              // If copy failed, drop the path to avoid later playback errors.
              pads[i] = pads[i].copyWith(path: null);
              changed = true;
            }
          }
        }
      }
      if (changed) {
        await _savePads();
      }
    }();

    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) async {
      final v = audioService.getRemainingTime();
      remainingSeconds.value = v;

      // Push updates to the secondary window if it exists
      final id = _timerWindowId;
      if (id != null) {
        try {
          await DesktopMultiWindow.invokeMethod(id, 'update_secs', v);
        } catch (_) {
          // Ignore if window was closed or not ready
        }
      }
    });
  }

  Future<void> playPad(int index) async {
    final pad = pads[index];
    if (pad.path == null) return;
    final path = pad.path!;
    // Guard against stale paths
    if (!kIsWeb && !File(path).existsSync()) {
      pads[index] = pads[index].copyWith(path: null);
      await _savePads();
      return;
    }
    if (audioService.isPlaying(path)) {
      await audioService.stopPath(path);
      return;
    }
    await audioService.playSound(path);
  }

  Future<void> assignFileToPad(int index) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    String finalPath = path;
    if (!kIsWeb) {
      try {
        finalPath = await storage.importAudioFile(path);
      } catch (_) {
        return;
      }
    }
    pads[index] = pads[index].copyWith(path: finalPath);
    await _savePads();
  }

  Future<void> addFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'ogg', 'flac', 'aac', 'm4a'],
    );
    if (result == null) return;

    final available = <int>[];
    for (var i = 0; i < pads.length; i++) {
      if (pads[i].path == null) available.add(i);
    }

    int idx = 0;
    for (final f in result.files) {
      if (idx >= available.length) break;
      if (f.path == null) continue;

      String finalPath = f.path!;
      if (!kIsWeb) {
        try {
          finalPath = await storage.importAudioFile(f.path!);
        } catch (_) {
          continue;
        }
      }
      final slot = available[idx++];
      pads[slot] = pads[slot].copyWith(path: finalPath);
    }
    await _savePads();
  }

  Future<void> stopAll() async {
    await audioService.stopAllSounds();
  }

  Future<void> clearAll() async {
    await audioService.clearAll();
    pads.assignAll([for (int i = 1; i <= 20; i++) Pad(name: 'Pad $i')]);
    await storage.clear();
    await storage.clearAudioLibrary();
  }

  Future<void> _savePads() async {
    await storage.savePads(pads.toList());
  }

  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    _ticker?.cancel();
    super.onClose();
  }

  void increment() => count.value++;

  void assignFilePathToPad(int index, String data) async {
    // drag-and-drop path assignment; copy to app library
    String finalPath = data;
    if (!kIsWeb) {
      try {
        finalPath = await storage.importAudioFile(data);
      } catch (_) {
        return;
      }
    }
    pads[index] = pads[index].copyWith(path: finalPath);
    await _savePads();
  }

  Future<void> showOverlay(BuildContext context) async {
    // Create secondary window and remember its id
    final window = await DesktopMultiWindow.createWindow('timer');
    _timerWindowId = window.windowId;
    // Pass a simple non-empty string; main.dart only checks args.isNotEmpty
    window
      ..setFrame(const Offset(100, 100) & const Size(800, 600))
      ..center()
      ..show();

    // Send an initial value so the overlay starts immediately
    final id = _timerWindowId;
    if (id != null) {
      // Allow a short delay for handler registration in the secondary window
      Future.delayed(const Duration(milliseconds: 150), () {
        final v = audioService.getRemainingTime();
        DesktopMultiWindow.invokeMethod(
          id,
          'update_secs',
          v,
        ).catchError((_) {});
      });
    }
  }
}
