// ============================================================================
//  Jota — playback
//
//  One stadium button and one hairline scrubber. The elapsed time is a figure,
//  so it is mono and zero-padded and it reads `00:47` exactly like the timer
//  inside the ring on the device's REC screen — the same datum in the same
//  face, which is the point.
//
//  The ADPCM archive is decoded to a WAV on first play (AudioStore), so the
//  first tap on a long note has a beat of latency and every later one does not.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/audio_store.dart';
import '../../design/format.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class PlaybackBar extends StatefulWidget {
  const PlaybackBar({
    super.key,
    required this.audio,
    required this.deviceId,
    required this.noteId,
    required this.durationSeconds,
  });

  final AudioStore audio;
  final String deviceId;
  final int noteId;
  final int durationSeconds;

  @override
  State<PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<PlaybackBar> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;

  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((PlayerState s) {
      if (!mounted) return;
      setState(() {});
      if (s.processingState == ProcessingState.completed) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (!_ready) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        // Decode ADPCM -> PCM WAV. Cached, so this cost is paid once per note.
        final file =
            await widget.audio.ensureWav(widget.deviceId, widget.noteId);
        if (file == null) {
          setState(() {
            _loading = false;
            _error = 'Audio file is missing';
          });
          return;
        }
        await _player.setFilePath(file.path);
        _ready = true;
      } on Exception catch (e) {
        setState(() {
          _loading = false;
          _error = 'Could not play this note ($e)';
        });
        return;
      }
      setState(() => _loading = false);
    }

    await _player.play();
  }

  @override
  Widget build(BuildContext context) {
    final JotaType t = context.type;
    final JotaColors c = context.ink;

    final Duration total =
        _player.duration ?? Duration(seconds: widget.durationSeconds);

    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (BuildContext context, AsyncSnapshot<Duration> snap) {
        final Duration pos = snap.data ?? Duration.zero;
        final double fraction = total.inMilliseconds <= 0
            ? 0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                SizedBox(
                  width: 132,
                  child: JotaButton(
                    label: _player.playing ? 'Pause' : 'Play',
                    primary: !_player.playing,
                    busy: _loading,
                    height: JotaRows.heightCompact,
                    onTap: _toggle,
                  ),
                ),
                const SizedBox(width: JotaGrid.gapM),
                // Both figures, both mono, both zero-padded — the same shape as
                // the ratio in a status slot.
                Text(fmtDuration(pos.inSeconds), style: t.figure),
                Text(
                  ' / ${fmtDuration(total.inSeconds)}',
                  style: t.reading.copyWith(color: c.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: JotaGrid.gapM),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails d) async {
                if (!_ready || total.inMilliseconds <= 0) return;
                final RenderBox box = context.findRenderObject()! as RenderBox;
                final double f =
                    (d.localPosition.dx / box.size.width).clamp(0.0, 1.0);
                await _player.seek(total * f);
              },
              child: JotaProgressBar(fraction: fraction),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: JotaGrid.gapS),
              Text(_error!, style: t.reading.copyWith(color: c.signal)),
            ],
          ],
        );
      },
    );
  }
}
