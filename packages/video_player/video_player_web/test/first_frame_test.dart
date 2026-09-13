// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_web/src/video_player.dart';
import 'package:web/web.dart' as web;

void main() {
  test('readiness waits for the frame callback and disposal cancels it', () async {
    final video = web.HTMLVideoElement();
    late JSFunction frameCallback;
    int? cancelled;
    video['requestVideoFrameCallback'] = ((JSFunction callback) {
      frameCallback = callback;
      return 7;
    }).toJS;
    video['cancelVideoFrameCallback'] = ((int id) {
      cancelled = id;
    }).toJS;
    final player = VideoPlayer(videoElement: video);
    final events = <VideoEvent>[];
    final StreamSubscription<VideoEvent> subscription = player.events.listen(events.add);
    player.initialize();
    video.dispatchEvent(web.Event('play'));
    await Future<void>.delayed(Duration.zero);
    expect(events.where((event) => event.eventType == VideoEventType.firstFrameRendered), isEmpty);
    frameCallback.callAsFunction(null, 0.toJS, JSObject());
    await Future<void>.delayed(Duration.zero);
    expect(
      events.where((event) => event.eventType == VideoEventType.firstFrameRendered),
      hasLength(1),
    );
    player.dispose();
    expect(cancelled, isNull);
    await subscription.cancel();

    final replacement = VideoPlayer(videoElement: video);
    final lateEvents = <VideoEvent>[];
    final StreamSubscription<VideoEvent> replacementSubscription = replacement.events.listen(
      lateEvents.add,
    );
    replacement.initialize();
    replacement.dispose();
    expect(cancelled, 7);
    frameCallback.callAsFunction(null, 0.toJS, JSObject());
    await Future<void>.delayed(Duration.zero);
    expect(
      lateEvents.where((event) => event.eventType == VideoEventType.firstFrameRendered),
      isEmpty,
    );
    await replacementSubscription.cancel();
  });
}
