#include "pipewire_capture.h"

#include <gst/app/gstappsink.h>
#include <gst/gst.h>
#include <gst/video/video.h>

#include <atomic>
#include <map>
#include <memory>
#include <string>

#include "flutter_webrtc.h"
#include "flutter_webrtc/flutter_web_r_t_c_plugin.h"

namespace {

using flutter_webrtc_plugin::FlutterWebRTCBase;
using libwebrtc::RTCMediaConstraints;
using libwebrtc::RTCMediaStream;
using libwebrtc::RTCMediaTrack;
using libwebrtc::RTCPeerConnectionFactory;
using libwebrtc::RTCVideoFrame;
using libwebrtc::RTCVideoSource;
using libwebrtc::RTCVideoTrack;
using libwebrtc::scoped_refptr;

constexpr char kChannelName[] = "localscreen/pipewire_capture";

// How long `start` waits for the first frame before it gives up.
constexpr guint kFirstFrameTimeoutSeconds = 8;

// A still screen produces no frames; PipeWire then repeats the last one at
// this interval so the encoder can always answer a key-frame request.
constexpr gint kKeepaliveMs = 100;

// flutter_webrtc owns the peer connection factory and the tables through
// which its Dart API finds local tracks, and keeps them protected. It hands
// out its instance for exactly this kind of integration
// (flutter_webrtc_plugin_get_shared_instance), so the members are reached
// through pointers to members rather than by patching the plugin.
//
// This compiles against the plugin's own headers: pubspec.yaml pins
// flutter_webrtc to one exact version, and linux/CMakeLists.txt mirrors the
// definitions the plugin is built with.
struct PluginAccess : FlutterWebRTCBase {
  using FlutterWebRTCBase::factory_;
  using FlutterWebRTCBase::local_streams_;
  using FlutterWebRTCBase::local_tracks_;
  using FlutterWebRTCBase::video_sources_;
};

struct Capture {
  std::string stream_id;
  std::string track_id;
  GstElement* pipeline = nullptr;
  guint bus_watch = 0;
  guint timeout = 0;
  scoped_refptr<RTCVideoSource> source;
  FlMethodChannel* channel = nullptr;
  // Answered when the first frame arrives; null afterwards.
  FlMethodCall* pending_start = nullptr;
  std::atomic<bool> first_frame{false};
  std::atomic<int> width{0};
  std::atomic<int> height{0};
};

std::map<std::string, std::unique_ptr<Capture>>& Captures() {
  static auto* captures = new std::map<std::string, std::unique_ptr<Capture>>();
  return *captures;
}

FlutterWebRTCBase* Plugin() {
  return flutter_webrtc_plugin_get_shared_instance();
}

std::string NewId() {
  g_autofree gchar* uuid = g_uuid_string_random();
  return uuid;
}

void RespondError(FlMethodCall* call, const char* code, const char* message) {
  fl_method_call_respond_error(call, code, message, nullptr, nullptr);
}

// Forgets the track in flutter_webrtc, in case Dart never got to own it.
void RemoveFromPlugin(const Capture& capture) {
  FlutterWebRTCBase* plugin = Plugin();
  if (plugin == nullptr) return;
  (plugin->*(&PluginAccess::video_sources_)).erase(capture.track_id);
  (plugin->*(&PluginAccess::local_tracks_)).erase(capture.track_id);
  (plugin->*(&PluginAccess::local_streams_)).erase(capture.stream_id);
}

// Stops the pipeline and releases everything `capture` holds.
void Teardown(Capture* capture) {
  if (capture->timeout != 0) g_source_remove(capture->timeout);
  if (capture->bus_watch != 0) g_source_remove(capture->bus_watch);
  if (capture->pipeline != nullptr) {
    // Joins the streaming thread, so no frame is delivered after this.
    gst_element_set_state(capture->pipeline, GST_STATE_NULL);
    gst_object_unref(capture->pipeline);
  }
  g_clear_object(&capture->pending_start);
  g_clear_object(&capture->channel);
  capture->source = nullptr;
}

// Ends a capture that failed or stopped by itself.
void Fail(const std::string& stream_id, const char* reason) {
  auto it = Captures().find(stream_id);
  if (it == Captures().end()) return;
  std::unique_ptr<Capture> capture = std::move(it->second);
  Captures().erase(it);
  if (capture->pending_start != nullptr) {
    RemoveFromPlugin(*capture);
    RespondError(capture->pending_start, "capture_failed", reason);
  } else {
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "streamId",
                             fl_value_new_string(stream_id.c_str()));
    fl_value_set_string_take(args, "reason", fl_value_new_string(reason));
    fl_method_channel_invoke_method(capture->channel, "ended", args, nullptr,
                                    nullptr, nullptr);
  }
  Teardown(capture.get());
}

// Streaming thread: converts one sample and hands it to WebRTC.
GstFlowReturn OnSample(GstAppSink* sink, gpointer user_data) {
  auto* capture = static_cast<Capture*>(user_data);
  GstSample* sample = gst_app_sink_pull_sample(sink);
  if (sample == nullptr) return GST_FLOW_OK;
  GstVideoInfo info;
  GstVideoFrame frame;
  if (gst_video_info_from_caps(&info, gst_sample_get_caps(sample)) &&
      gst_video_frame_map(&frame, &info, gst_sample_get_buffer(sample),
                          GST_MAP_READ)) {
    const int width = GST_VIDEO_FRAME_WIDTH(&frame);
    const int height = GST_VIDEO_FRAME_HEIGHT(&frame);
    scoped_refptr<RTCVideoFrame> rtc_frame = RTCVideoFrame::Create(
        width, height,
        static_cast<const uint8_t*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 0)),
        GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 0),
        static_cast<const uint8_t*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 1)),
        GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 1),
        static_cast<const uint8_t*>(GST_VIDEO_FRAME_PLANE_DATA(&frame, 2)),
        GST_VIDEO_FRAME_PLANE_STRIDE(&frame, 2));
    gst_video_frame_unmap(&frame);
    if (rtc_frame.get() != nullptr) {
      capture->source->OnCapturedFrame(rtc_frame);
      capture->width = width;
      capture->height = height;
      capture->first_frame = true;
    }
  }
  gst_sample_unref(sample);
  return GST_FLOW_OK;
}

// Main loop: answers `start` once frames flow, or gives up after the timeout.
gboolean OnStartPoll(gpointer user_data) {
  static constexpr guint kPollsPerSecond = 20;
  auto* key = static_cast<std::pair<std::string, guint>*>(user_data);
  auto it = Captures().find(key->first);
  if (it == Captures().end() || it->second->pending_start == nullptr) {
    return G_SOURCE_REMOVE;
  }
  Capture* capture = it->second.get();
  if (capture->first_frame) {
    capture->timeout = 0;
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "streamId",
                             fl_value_new_string(capture->stream_id.c_str()));
    fl_value_set_string_take(result, "trackId",
                             fl_value_new_string(capture->track_id.c_str()));
    fl_value_set_string_take(result, "width", fl_value_new_int(capture->width));
    fl_value_set_string_take(result, "height",
                             fl_value_new_int(capture->height));
    fl_method_call_respond_success(capture->pending_start, result, nullptr);
    g_clear_object(&capture->pending_start);
    return G_SOURCE_REMOVE;
  }
  if (++key->second >= kFirstFrameTimeoutSeconds * kPollsPerSecond) {
    capture->timeout = 0;
    Fail(key->first, "no frame arrived");
    return G_SOURCE_REMOVE;
  }
  return G_SOURCE_CONTINUE;
}

void FreeStartPoll(gpointer user_data) {
  delete static_cast<std::pair<std::string, guint>*>(user_data);
}

// Main loop: pipeline errors and end-of-stream.
gboolean OnBusMessage(GstBus*, GstMessage* message, gpointer user_data) {
  const std::string stream_id = *static_cast<std::string*>(user_data);
  switch (GST_MESSAGE_TYPE(message)) {
    case GST_MESSAGE_ERROR: {
      g_autoptr(GError) error = nullptr;
      gst_message_parse_error(message, &error, nullptr);
      g_warning("pipewire capture: %s", error->message);
      // Removing the capture also removes this watch; the source is being
      // dispatched, so tell Teardown not to remove it a second time.
      auto it = Captures().find(stream_id);
      if (it != Captures().end()) it->second->bus_watch = 0;
      Fail(stream_id, error->message);
      return G_SOURCE_REMOVE;
    }
    case GST_MESSAGE_EOS: {
      auto it = Captures().find(stream_id);
      if (it != Captures().end()) it->second->bus_watch = 0;
      Fail(stream_id, "the stream ended");
      return G_SOURCE_REMOVE;
    }
    default:
      return G_SOURCE_CONTINUE;
  }
}

void FreeString(gpointer user_data) {
  delete static_cast<std::string*>(user_data);
}

gint64 IntArg(FlValue* args, const char* key) {
  FlValue* value = fl_value_lookup_string(args, key);
  return value != nullptr && fl_value_get_type(value) == FL_VALUE_TYPE_INT
             ? fl_value_get_int(value)
             : 0;
}

void Start(FlMethodChannel* channel, FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  if (fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    RespondError(call, "bad_arguments", "expected a map");
    return;
  }
  const gint64 node = IntArg(args, "node");
  const gint64 fps = IntArg(args, "fps") > 0 ? IntArg(args, "fps") : 60;
  const gint64 width = IntArg(args, "width");
  const gint64 height = IntArg(args, "height");

  FlutterWebRTCBase* plugin = Plugin();
  scoped_refptr<RTCPeerConnectionFactory> factory =
      plugin == nullptr ? nullptr : plugin->*(&PluginAccess::factory_);
  if (factory.get() == nullptr) {
    RespondError(call, "not_ready", "WebRTC is not initialized");
    return;
  }

  // The size, when given, is what sizes a virtual monitor: Mutter creates it
  // to match the format its first consumer asks for.
  g_autofree gchar* size =
      width > 0 && height > 0
          ? g_strdup_printf(",width=%" G_GINT64_FORMAT ",height=%" G_GINT64_FORMAT,
                            width, height)
          : g_strdup("");
  g_autofree gchar* description = g_strdup_printf(
      "pipewiresrc name=src path=%" G_GINT64_FORMAT
      " do-timestamp=true ! video/x-raw%s,max-framerate=%" G_GINT64_FORMAT
      "/1 ! videoconvert ! video/x-raw,format=I420 ! "
      "appsink name=sink sync=false max-buffers=2 drop=true",
      node, size, fps);
  g_autoptr(GError) error = nullptr;
  GstElement* pipeline = gst_parse_launch(description, &error);
  if (pipeline == nullptr || error != nullptr) {
    RespondError(call, "pipeline", error != nullptr ? error->message : "failed");
    if (pipeline != nullptr) gst_object_unref(pipeline);
    return;
  }

  auto capture = std::make_unique<Capture>();
  capture->stream_id = NewId();
  capture->track_id = NewId();
  capture->pipeline = pipeline;
  capture->channel = FL_METHOD_CHANNEL(g_object_ref(channel));
  capture->pending_start = FL_METHOD_CALL(g_object_ref(call));

  capture->source = factory->CreateCustomVideoSource("screen_capture_input",
                                                     RTCMediaConstraints::Create());
  scoped_refptr<RTCVideoTrack> track =
      capture->source.get() == nullptr
          ? nullptr
          : factory->CreateVideoTrack(capture->source, capture->track_id.c_str());
  scoped_refptr<RTCMediaStream> stream =
      factory->CreateStream(capture->stream_id.c_str());
  if (track.get() == nullptr || stream.get() == nullptr) {
    Teardown(capture.get());
    RespondError(call, "track", "could not create the video track");
    return;
  }
  stream->AddTrack(track);
  // Registered exactly as flutter_webrtc registers its own capture tracks, so
  // the Dart API (addTrack, stop, dispose) treats this one the same way.
  (plugin->*(&PluginAccess::local_tracks_))[capture->track_id] = track;
  (plugin->*(&PluginAccess::video_sources_))[capture->track_id] = {capture->source};
  (plugin->*(&PluginAccess::local_streams_))[capture->stream_id] = stream;

  g_autoptr(GstElement) src = gst_bin_get_by_name(GST_BIN(pipeline), "src");
  if (g_object_class_find_property(G_OBJECT_GET_CLASS(src), "keepalive-time") !=
      nullptr) {
    g_object_set(src, "keepalive-time", kKeepaliveMs, nullptr);
  }
  g_autoptr(GstElement) sink = gst_bin_get_by_name(GST_BIN(pipeline), "sink");
  GstAppSinkCallbacks callbacks = {};
  callbacks.new_sample = OnSample;
  gst_app_sink_set_callbacks(GST_APP_SINK(sink), &callbacks, capture.get(),
                             nullptr);

  g_autoptr(GstBus) bus = gst_element_get_bus(pipeline);
  capture->bus_watch = gst_bus_add_watch_full(
      bus, G_PRIORITY_DEFAULT, OnBusMessage,
      new std::string(capture->stream_id), FreeString);
  capture->timeout = g_timeout_add_full(
      G_PRIORITY_DEFAULT, 50, OnStartPoll,
      new std::pair<std::string, guint>(capture->stream_id, 0), FreeStartPoll);

  const std::string stream_id = capture->stream_id;
  Captures()[stream_id] = std::move(capture);
  if (gst_element_set_state(pipeline, GST_STATE_PLAYING) ==
      GST_STATE_CHANGE_FAILURE) {
    Fail(stream_id, "the pipeline did not start");
  }
}

void Stop(FlMethodCall* call) {
  FlValue* args = fl_method_call_get_args(call);
  FlValue* id = fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                    ? fl_value_lookup_string(args, "streamId")
                    : nullptr;
  if (id != nullptr && fl_value_get_type(id) == FL_VALUE_TYPE_STRING) {
    auto it = Captures().find(fl_value_get_string(id));
    if (it != Captures().end()) {
      std::unique_ptr<Capture> capture = std::move(it->second);
      Captures().erase(it);
      if (capture->pending_start != nullptr) {
        RemoveFromPlugin(*capture);
        RespondError(capture->pending_start, "stopped", "stopped before it started");
      }
      Teardown(capture.get());
    }
  }
  fl_method_call_respond_success(call, nullptr, nullptr);
}

// Whether every element of the capture pipeline is installed.
bool Supported() {
  for (const char* name : {"pipewiresrc", "videoconvert", "appsink"}) {
    g_autoptr(GstElementFactory) factory = gst_element_factory_find(name);
    if (factory == nullptr) return false;
  }
  return true;
}

void OnMethodCall(FlMethodChannel* channel, FlMethodCall* call, gpointer) {
  const gchar* method = fl_method_call_get_name(call);
  if (g_strcmp0(method, "start") == 0) {
    Start(channel, call);
  } else if (g_strcmp0(method, "stop") == 0) {
    Stop(call);
  } else if (g_strcmp0(method, "supported") == 0) {
    g_autoptr(FlValue) supported = fl_value_new_bool(Supported());
    fl_method_call_respond_success(call, supported, nullptr);
  } else {
    fl_method_call_respond_not_implemented(call, nullptr);
  }
}

}  // namespace

void pipewire_capture_register(FlBinaryMessenger* messenger) {
  gst_init(nullptr, nullptr);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  // Lives as long as the engine, like the plugins' own channels.
  FlMethodChannel* channel =
      fl_method_channel_new(messenger, kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, OnMethodCall, nullptr,
                                            nullptr);
}
