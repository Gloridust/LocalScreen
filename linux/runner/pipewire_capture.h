#ifndef RUNNER_PIPEWIRE_CAPTURE_H_
#define RUNNER_PIPEWIRE_CAPTURE_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Registers the `localscreen/pipewire_capture` method channel.
//
// It turns a PipeWire video node (one that this process may already read,
// such as a Mutter screen-cast stream it created itself) into a local
// flutter_webrtc video track, without going through the desktop portal and
// its picker dialog.
//
//   start({node: int, fps: int, width: int?, height: int?})
//       -> {streamId, trackId, width, height}   once the first frame arrived
//   stop({streamId: String})
//   supported() -> bool    whether the GStreamer elements it needs exist
//
// and, from native to Dart, `ended({streamId, reason})` when a running
// capture stops on its own (the node went away or the pipeline failed).
void pipewire_capture_register(FlBinaryMessenger* messenger);

G_END_DECLS

#endif  // RUNNER_PIPEWIRE_CAPTURE_H_
