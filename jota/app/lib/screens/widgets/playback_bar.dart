// ============================================================================
//  Jota — playback
//
//  One stadium button and one hairline scrubber. The elapsed time is a figure, so
//  it is mono and zero-padded and it reads `00:47` exactly like the timer inside
//  the ring on the device's REC screen — the same datum in the same face, which is
//  the point.
//
//  Talks to a NotePlayer, never to an audio plugin. The real one decodes the
//  ADPCM archive and makes sound; the preview one advances a timer and does not.
// ============================================================================
import 'dart:async';

import 'package:flutter/material.dart';

import '../../audio/note_player.dart';
import '../../design/format.dart';
import '../../design/theme.dart';
import '../../design/widgets.dart';

class PlaybackBar extends StatefulWidget {
  const PlaybackBar({
    super.key,
    required this.createPlayer,
    required this.deviceId,
    required this.noteId,
    required this.durationSeconds,
  });

  /// A factory rather than an instance: this widget owns the player's lifetime
  /// and disposes it, and a note change should get a fresh one.
  final NotePlayer Function() createPlayer;

  final String deviceId;
  final int noteId;
  final int durationSeconds;

  @override
  State<PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<PlaybackBar> {
  late final NotePlayer _player = widget.createPlayer();
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration>? _positionSub;

  Duration _position = Duration.zero;
  bool _loading = false;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _playingSub = _player.playingChanges.listen((_) {
      if (mounted) setState(() {});
    });
    _positionSub = _player.position.listen((Duration p) {
      if (!mounted) return;
      setState(() => _position = p);

      // Neither implementation reports "finished" as a stop, so the bar would
      // otherwise sit at the end still showing PAUSE.
      final Duration? total = _player.duration;
      if (total != null &&
          total > Duration.zero &&
          p >= total &&
          _player.playing) {
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
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
        final bool ok = await _player.load(widget.deviceId, widget.noteId);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _loading = false;
            _error = 'Audio file is missing';
          });
          return;
        }
        _ready = true;
      } on Exception catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Could not play this note ($e)';
        });
        return;
      }
      if (!mounted) return;
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
    final double fraction = total.inMilliseconds <= 0
        ? 0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

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
            // Both figures, both mono, both zero-padded — the same shape as a
            // ratio in a status slot.
            Text(fmtDuration(_position.inSeconds), style: t.figure),
            Text(
              ' / ${fmtDuration(total.inSeconds)}',
              style: t.reading.copyWith(color: c.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: JotaGrid.gapM),
        _Scrubber(
          fraction: fraction,
          onSeek: (double f) async {
            if (total.inMilliseconds <= 0) return;
            await _player.seek(total * f);
          },
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: JotaGrid.gapS),
          Text(_error!, style: t.reading.copyWith(color: c.signal)),
        ],
      ],
    );
  }
}

/// Split out so the tap maths uses THIS widget's box rather than the whole
/// column's — the previous version measured the wrong render object and seeked
/// to the wrong place on anything but a full-width bar.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.fraction, required this.onSeek});

  final double fraction;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (TapDownDetails d) {
            if (box.maxWidth <= 0) return;
            onSeek((d.localPosition.dx / box.maxWidth).clamp(0.0, 1.0));
          },
          child: JotaProgressBar(fraction: fraction),
        );
      },
    );
  }
}
