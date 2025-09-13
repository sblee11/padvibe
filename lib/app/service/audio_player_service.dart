import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:get/get.dart';

class AudioPlayerService extends GetxService {
  final audioData = AudioData(GetSamplesKind.linear);
  final SoLoud soloud = SoLoud.instance;

  final isInitialized = false.obs;

  final Map<String, AudioSource> _loadedSources = {};
  final Map<SoundHandle, AudioSource> _activeSounds = {};
  final RxList<SoundHandle> activeHandles = <SoundHandle>[].obs;
  // Track which path each active handle belongs to (no caching of sources).
  final Map<SoundHandle, String> _handlePath = {};

  @override
  void onInit() {
    super.onInit();
    _initialize(); // fire-and-forget is fine; we gate on isInitialized
  }

  Future<void> _initialize() async {
    await soloud.init(); // await to ensure ready
    isInitialized.value = true;
    soloud.setVisualizationEnabled(true);
  }

  @override
  void onClose() {
    // It’s OK that onClose isn’t async—kick off cleanup and deinit.
    () async {
      await stopAllSounds();
      await soloud.disposeAllSources();
      soloud.deinit(); // stops engine and frees everything
      audioData.dispose();
    }();
    super.onClose();
  }

  Future<AudioSource?> loadSound(String path) async {
    // Do not cache; just create a streaming source from disk and return it.
    try {
      final source = await soloud.loadFile(path, mode: LoadMode.disk);
      return source;
    } catch (_) {
      return null;
    }
  }

  Future<void> playSound(String path) async {
    await ensureInitialized();
    final source = await loadSound(path);
    if (source == null) return;

    final newHandle = await soloud.play(source);
    _activeSounds[newHandle] = source;
    _handlePath[newHandle] = path;
    activeHandles.add(newHandle);
  }

  Future<void> stopAllSounds() async {
    if (!isInitialized.value) return;
    // stop returns Future<void>; wait on all
    await Future.wait(
      activeHandles.map((h) async {
        await soloud.stop(h);
        _activeSounds.remove(h);
        _handlePath.remove(h);
      }),
    );
    activeHandles.clear();
  }

  Future<void> clearAll() async {
    await stopAllSounds();
    // No cached sources to dispose anymore; keep map for compatibility.
    await Future.wait(_loadedSources.values.map(soloud.disposeSource));
    _loadedSources.clear();
  }

  Float32List getMasterFft() {
    if (!isInitialized.value || activeHandles.isEmpty) {
      return Float32List(256);
    }
    audioData.updateSamples();
    final samples = audioData.getAudioData(alwaysReturnData: false);
    if (samples.isEmpty) return Float32List(256);
    final take = samples.length >= 256 ? 256 : samples.length;
    return samples.sublist(0, take);
  }

  double getRemainingTime() {
    if (!isInitialized.value) return 0.0;
    if (activeHandles.isEmpty) return 0.0;

    Duration maxRemainingTime = Duration.zero;
    for (final handle in activeHandles.toList()) {
      final source = _activeSounds[handle];
      if (source == null) continue;

      final length = soloud.getLength(source); // Duration
      final position = soloud.getPosition(handle); // Duration
      final remaining = length - position;

      // Optional: prune finished handles
      if (remaining.isNegative || remaining == Duration.zero) {
        _activeSounds.remove(handle);
        _handlePath.remove(handle);
        activeHandles.remove(handle);
        continue;
      }
      if (remaining > maxRemainingTime) {
        maxRemainingTime = remaining;
      }
    }
    return maxRemainingTime.inMilliseconds / 1000.0;
  }

  double? getRemainingFractionForPath(String path) {
    if (!isInitialized.value) return null;
    if (activeHandles.isEmpty) return null;

    double? best;
    for (final entry in _handlePath.entries.toList()) {
      if (entry.value != path) continue;
      final handle = entry.key;
      final source = _activeSounds[handle];
      if (source == null) continue;

      final length = soloud.getLength(source);
      if (length.inMilliseconds <= 0) continue;

      final position = soloud.getPosition(handle);
      final remaining = length - position;

      if (remaining.isNegative || remaining == Duration.zero) {
        // prune finished
        _activeSounds.remove(handle);
        _handlePath.remove(handle);
        activeHandles.remove(handle);
        continue;
      }

      final frac = remaining.inMilliseconds / length.inMilliseconds;
      if (best == null || frac > best) best = frac;
    }
    return best;
  }

  Future<void> ensureInitialized() async {
    if (!isInitialized.value) {
      await _initialize();
    }
  }

  // Stop all active handles that were started from a specific file path.
  Future<void> stopPath(String path) async {
    final toStop = _handlePath.entries
        .where((e) => e.value == path)
        .map((e) => e.key)
        .toList();
    for (final h in toStop) {
      await soloud.stop(h);
      _activeSounds.remove(h);
      _handlePath.remove(h);
      activeHandles.remove(h);
    }
  }

  // Unload is effectively a no-op without caching; keep for API compatibility.
  Future<void> unloadPath(String path) async {
    await stopPath(path);
    final source = _loadedSources.remove(path);
    if (source != null) {
      await soloud.disposeSource(source);
    }
  }

  bool isPlaying(String path) {
    return _handlePath.values.any((p) => p == path);
  }

  // Preload is a no-op when streaming directly from disk.
  Future<void> preloadSounds(Iterable<String> paths) async {
    await ensureInitialized();
    // intentionally no-op
  }
}
