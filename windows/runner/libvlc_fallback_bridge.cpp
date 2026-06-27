#include "libvlc_fallback_bridge.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter_plugin_registrar.h>
#include <flutter_texture_registrar.h>
#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace {

constexpr char kChannelName[] = "elaina/windows_libvlc_fallback";
constexpr char kNoVideoTitleArg[] = "--no-video-title-show";
constexpr char kLibVlcChromaRv32[] = "RV32";

struct libvlc_instance_t;
struct libvlc_media_t;
struct libvlc_media_player_t;
using libvlc_time_t = long long;
using libvlc_video_lock_cb = void* (*)(void*, void**);
using libvlc_video_unlock_cb = void (*)(void*, void*, void* const*);
using libvlc_video_display_cb = void (*)(void*, void*);
using libvlc_video_format_cb = unsigned (*)(void**, char*, unsigned*,
                                            unsigned*, unsigned*, unsigned*);
using libvlc_video_cleanup_cb = void (*)(void*);

using libvlc_new_fn = libvlc_instance_t* (*)(int, const char* const*);
using libvlc_release_fn = void (*)(libvlc_instance_t*);
using libvlc_get_version_fn = const char* (*)();
using libvlc_media_new_path_fn = libvlc_media_t* (*)(libvlc_instance_t*,
                                                     const char*);
using libvlc_media_release_fn = void (*)(libvlc_media_t*);
using libvlc_media_player_new_from_media_fn =
    libvlc_media_player_t* (*)(libvlc_media_t*);
using libvlc_media_player_release_fn = void (*)(libvlc_media_player_t*);
using libvlc_media_player_play_fn = int (*)(libvlc_media_player_t*);
using libvlc_media_player_pause_fn = void (*)(libvlc_media_player_t*);
using libvlc_media_player_stop_fn = void (*)(libvlc_media_player_t*);
using libvlc_media_player_set_time_fn = void (*)(libvlc_media_player_t*,
                                                 libvlc_time_t);
using libvlc_media_player_get_time_fn = libvlc_time_t (*)(
    libvlc_media_player_t*);
using libvlc_media_player_get_length_fn = libvlc_time_t (*)(
    libvlc_media_player_t*);
using libvlc_media_player_is_playing_fn = int (*)(libvlc_media_player_t*);
using libvlc_video_set_callbacks_fn = void (*)(libvlc_media_player_t*,
                                               libvlc_video_lock_cb,
                                               libvlc_video_unlock_cb,
                                               libvlc_video_display_cb, void*);
using libvlc_video_set_format_callbacks_fn =
    void (*)(libvlc_media_player_t*, libvlc_video_format_cb,
             libvlc_video_cleanup_cb);

struct LibVlcApi {
  HMODULE module = nullptr;
  libvlc_new_fn libvlc_new = nullptr;
  libvlc_release_fn libvlc_release = nullptr;
  libvlc_get_version_fn libvlc_get_version = nullptr;
  libvlc_media_new_path_fn libvlc_media_new_path = nullptr;
  libvlc_media_release_fn libvlc_media_release = nullptr;
  libvlc_media_player_new_from_media_fn libvlc_media_player_new_from_media =
      nullptr;
  libvlc_media_player_release_fn libvlc_media_player_release = nullptr;
  libvlc_media_player_play_fn libvlc_media_player_play = nullptr;
  libvlc_media_player_pause_fn libvlc_media_player_pause = nullptr;
  libvlc_media_player_stop_fn libvlc_media_player_stop = nullptr;
  libvlc_media_player_set_time_fn libvlc_media_player_set_time = nullptr;
  libvlc_media_player_get_time_fn libvlc_media_player_get_time = nullptr;
  libvlc_media_player_get_length_fn libvlc_media_player_get_length = nullptr;
  libvlc_media_player_is_playing_fn libvlc_media_player_is_playing = nullptr;
  libvlc_video_set_callbacks_fn libvlc_video_set_callbacks = nullptr;
  libvlc_video_set_format_callbacks_fn libvlc_video_set_format_callbacks =
      nullptr;
};

struct VlcSession {
  LibVlcApi api;
  libvlc_instance_t* instance = nullptr;
  libvlc_media_player_t* player = nullptr;
  std::string failure;
  int64_t texture_id = -1;
  std::mutex video_mutex;
  std::vector<uint8_t> decode_buffer;
  std::vector<uint8_t> frame_buffer;
  FlutterDesktopPixelBuffer pixel_buffer = {};
  unsigned video_width = 0;
  unsigned video_height = 0;
  unsigned video_pitch = 0;
  bool has_frame = false;
};

std::map<int64_t, std::unique_ptr<VlcSession>> g_sessions;
int64_t g_next_session_id = 1;
FlutterDesktopTextureRegistrarRef g_texture_registrar = nullptr;

std::string Utf8FromWide(const std::wstring& value) {
  if (value.empty()) {
    return std::string();
  }
  const int size = WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0, nullptr, nullptr);
  if (size <= 0) {
    return std::string();
  }
  std::string output(static_cast<size_t>(size - 1), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), -1, output.data(), size,
                      nullptr, nullptr);
  return output;
}

std::wstring WideFromUtf8(const std::string& value) {
  if (value.empty()) {
    return std::wstring();
  }
  const int size = MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, nullptr,
                                       0);
  if (size <= 0) {
    return std::wstring();
  }
  std::wstring output(static_cast<size_t>(size - 1), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, value.c_str(), -1, output.data(), size);
  return output;
}

flutter::EncodableMap MapOf(
    std::initializer_list<std::pair<std::string, flutter::EncodableValue>>
        entries) {
  flutter::EncodableMap map;
  for (const auto& entry : entries) {
    map[flutter::EncodableValue(entry.first)] = entry.second;
  }
  return map;
}

std::optional<std::string> StringArg(const flutter::EncodableMap& args,
                                     const char* key) {
  const auto found = args.find(flutter::EncodableValue(key));
  if (found == args.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<std::string>(&found->second)) {
    return *value;
  }
  return std::nullopt;
}

std::optional<int64_t> IntArg(const flutter::EncodableMap& args,
                              const char* key) {
  const auto found = args.find(flutter::EncodableValue(key));
  if (found == args.end()) {
    return std::nullopt;
  }
  if (const auto* value = std::get_if<int32_t>(&found->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&found->second)) {
    return *value;
  }
  return std::nullopt;
}

const flutter::EncodableMap* ArgsMap(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  const flutter::EncodableValue* arguments = call.arguments();
  if (arguments == nullptr) {
    return nullptr;
  }
  return std::get_if<flutter::EncodableMap>(arguments);
}

FARPROC Symbol(HMODULE module, const char* name) {
  return module == nullptr ? nullptr : GetProcAddress(module, name);
}

const FlutterDesktopPixelBuffer* CopyVlcPixelBuffer(VlcSession* session,
                                                    size_t /*width*/,
                                                    size_t /*height*/) {
  if (session == nullptr) {
    return nullptr;
  }
  std::lock_guard<std::mutex> lock(session->video_mutex);
  if (!session->has_frame || session->frame_buffer.empty()) {
    return nullptr;
  }
  session->pixel_buffer.buffer = session->frame_buffer.data();
  session->pixel_buffer.width = session->video_width;
  session->pixel_buffer.height = session->video_height;
  session->pixel_buffer.release_callback = nullptr;
  session->pixel_buffer.release_context = nullptr;
  return &session->pixel_buffer;
}

const FlutterDesktopPixelBuffer* VlcPixelBufferTextureCallback(
    size_t width,
    size_t height,
    void* user_data) {
  return CopyVlcPixelBuffer(static_cast<VlcSession*>(user_data), width, height);
}

unsigned VlcVideoFormat(void** opaque, char* chroma, unsigned* width,
                        unsigned* height, unsigned* pitches,
                        unsigned* lines) {
  auto* session = static_cast<VlcSession*>(*opaque);
  if (session == nullptr || width == nullptr || height == nullptr ||
      pitches == nullptr || lines == nullptr) {
    return 0;
  }

  std::memcpy(chroma, kLibVlcChromaRv32, 4);
  const unsigned frame_width = *width;
  const unsigned frame_height = *height;
  const unsigned pitch = frame_width * 4;
  {
    std::lock_guard<std::mutex> lock(session->video_mutex);
    session->video_width = frame_width;
    session->video_height = frame_height;
    session->video_pitch = pitch;
    session->decode_buffer.assign(static_cast<size_t>(pitch) * frame_height,
                                  0);
    session->frame_buffer.assign(static_cast<size_t>(pitch) * frame_height, 0);
    session->has_frame = false;
  }
  pitches[0] = pitch;
  lines[0] = frame_height;
  return 1;
}

void VlcVideoCleanup(void* opaque) {
  auto* session = static_cast<VlcSession*>(opaque);
  if (session == nullptr) {
    return;
  }
  std::lock_guard<std::mutex> lock(session->video_mutex);
  session->decode_buffer.clear();
  session->frame_buffer.clear();
  session->has_frame = false;
}

void* VlcVideoLock(void* opaque, void** planes) {
  auto* session = static_cast<VlcSession*>(opaque);
  if (session == nullptr || planes == nullptr) {
    return nullptr;
  }
  session->video_mutex.lock();
  if (session->decode_buffer.empty()) {
    session->video_mutex.unlock();
    return nullptr;
  }
  planes[0] = session->decode_buffer.data();
  return nullptr;
}

void VlcVideoUnlock(void* opaque, void* /*picture*/,
                    void* const* /*planes*/) {
  auto* session = static_cast<VlcSession*>(opaque);
  if (session == nullptr) {
    return;
  }
  if (!session->decode_buffer.empty() &&
      session->decode_buffer.size() == session->frame_buffer.size()) {
    std::copy(session->decode_buffer.begin(), session->decode_buffer.end(),
              session->frame_buffer.begin());
    session->has_frame = true;
  }
  session->video_mutex.unlock();
}

void VlcVideoDisplay(void* opaque, void* /*picture*/) {
  auto* session = static_cast<VlcSession*>(opaque);
  if (session == nullptr || g_texture_registrar == nullptr ||
      session->texture_id < 0) {
    return;
  }
  FlutterDesktopTextureRegistrarMarkExternalTextureFrameAvailable(
      g_texture_registrar, session->texture_id);
}

bool LoadLibVlcApi(const std::string& libvlc_path, LibVlcApi* api,
                   std::string* reason) {
  const std::wstring wide_path = WideFromUtf8(libvlc_path);
  HMODULE module = LoadLibraryW(wide_path.c_str());
  if (module == nullptr) {
    *reason = "LoadLibraryW failed for libvlc.dll.";
    return false;
  }

  api->module = module;
  api->libvlc_new =
      reinterpret_cast<libvlc_new_fn>(Symbol(module, "libvlc_new"));
  api->libvlc_release =
      reinterpret_cast<libvlc_release_fn>(Symbol(module, "libvlc_release"));
  api->libvlc_get_version = reinterpret_cast<libvlc_get_version_fn>(
      Symbol(module, "libvlc_get_version"));
  api->libvlc_media_new_path = reinterpret_cast<libvlc_media_new_path_fn>(
      Symbol(module, "libvlc_media_new_path"));
  api->libvlc_media_release = reinterpret_cast<libvlc_media_release_fn>(
      Symbol(module, "libvlc_media_release"));
  api->libvlc_media_player_new_from_media =
      reinterpret_cast<libvlc_media_player_new_from_media_fn>(
          Symbol(module, "libvlc_media_player_new_from_media"));
  api->libvlc_media_player_release =
      reinterpret_cast<libvlc_media_player_release_fn>(
          Symbol(module, "libvlc_media_player_release"));
  api->libvlc_media_player_play =
      reinterpret_cast<libvlc_media_player_play_fn>(
          Symbol(module, "libvlc_media_player_play"));
  api->libvlc_media_player_pause =
      reinterpret_cast<libvlc_media_player_pause_fn>(
          Symbol(module, "libvlc_media_player_pause"));
  api->libvlc_media_player_stop =
      reinterpret_cast<libvlc_media_player_stop_fn>(
          Symbol(module, "libvlc_media_player_stop"));
  api->libvlc_media_player_set_time =
      reinterpret_cast<libvlc_media_player_set_time_fn>(
          Symbol(module, "libvlc_media_player_set_time"));
  api->libvlc_media_player_get_time =
      reinterpret_cast<libvlc_media_player_get_time_fn>(
          Symbol(module, "libvlc_media_player_get_time"));
  api->libvlc_media_player_get_length =
      reinterpret_cast<libvlc_media_player_get_length_fn>(
          Symbol(module, "libvlc_media_player_get_length"));
  api->libvlc_media_player_is_playing =
      reinterpret_cast<libvlc_media_player_is_playing_fn>(
          Symbol(module, "libvlc_media_player_is_playing"));
  api->libvlc_video_set_callbacks =
      reinterpret_cast<libvlc_video_set_callbacks_fn>(
          Symbol(module, "libvlc_video_set_callbacks"));
  api->libvlc_video_set_format_callbacks =
      reinterpret_cast<libvlc_video_set_format_callbacks_fn>(
          Symbol(module, "libvlc_video_set_format_callbacks"));

  if (api->libvlc_new == nullptr || api->libvlc_release == nullptr ||
      api->libvlc_media_new_path == nullptr ||
      api->libvlc_media_release == nullptr ||
      api->libvlc_media_player_new_from_media == nullptr ||
      api->libvlc_media_player_release == nullptr ||
      api->libvlc_media_player_play == nullptr ||
      api->libvlc_media_player_pause == nullptr ||
      api->libvlc_media_player_stop == nullptr ||
      api->libvlc_media_player_set_time == nullptr ||
      api->libvlc_media_player_get_time == nullptr ||
      api->libvlc_media_player_get_length == nullptr ||
      api->libvlc_media_player_is_playing == nullptr ||
      api->libvlc_video_set_callbacks == nullptr ||
      api->libvlc_video_set_format_callbacks == nullptr) {
    FreeLibrary(module);
    api->module = nullptr;
    *reason = "libvlc.dll is missing required playback symbols.";
    return false;
  }

  return true;
}

void ReleaseSession(VlcSession* session) {
  if (session == nullptr) {
    return;
  }
  if (session->player != nullptr) {
    session->api.libvlc_media_player_stop(session->player);
    session->api.libvlc_media_player_release(session->player);
    session->player = nullptr;
  }
  if (session->instance != nullptr) {
    session->api.libvlc_release(session->instance);
    session->instance = nullptr;
  }
  if (session->texture_id >= 0 && g_texture_registrar != nullptr) {
    FlutterDesktopTextureRegistrarUnregisterExternalTexture(
        g_texture_registrar, session->texture_id, nullptr, nullptr);
    session->texture_id = -1;
  }
  if (session->api.module != nullptr) {
    FreeLibrary(session->api.module);
    session->api.module = nullptr;
  }
}

VlcSession* SessionForId(int64_t backend_id) {
  const auto found = g_sessions.find(backend_id);
  if (found == g_sessions.end()) {
    return nullptr;
  }
  return found->second.get();
}

void Success(flutter::MethodResult<flutter::EncodableValue>* result,
             flutter::EncodableMap map) {
  result->Success(flutter::EncodableValue(map));
}

void Error(flutter::MethodResult<flutter::EncodableValue>* result,
           const std::string& message) {
  result->Error("windows_libvlc_fallback", message);
}

void HandleProbeRuntime(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (g_texture_registrar == nullptr) {
    Success(result.get(),
            MapOf({{"available", false},
                   {"reason", "Flutter texture registrar is unavailable."},
                   {"textureSurface", false}}));
    return;
  }
  const auto libvlc_path = StringArg(args, "libvlcPath");
  if (!libvlc_path.has_value()) {
    Success(result.get(), MapOf({{"available", false},
                                 {"reason", "libvlcPath is required."},
                                 {"textureSurface", false}}));
    return;
  }
  LibVlcApi api;
  std::string reason;
  if (!LoadLibVlcApi(*libvlc_path, &api, &reason)) {
    Success(result.get(),
            MapOf({{"available", false},
                   {"reason", reason},
                   {"textureSurface", false}}));
    return;
  }
  const char* version =
      api.libvlc_get_version == nullptr ? nullptr : api.libvlc_get_version();
  if (api.module != nullptr) {
    FreeLibrary(api.module);
  }
  Success(result.get(),
          MapOf({{"available", true},
                 {"textureSurface", true},
                 {"version", version == nullptr ? "" : std::string(version)}}));
}

void HandleInitialize(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (g_texture_registrar == nullptr) {
    Error(result.get(), "Flutter texture registrar is unavailable.");
    return;
  }
  const auto libvlc_path = StringArg(args, "libvlcPath");
  const auto plugins_directory = StringArg(args, "pluginsDirectory");
  if (!libvlc_path.has_value() || !plugins_directory.has_value()) {
    Error(result.get(), "libvlcPath and pluginsDirectory are required.");
    return;
  }

  auto session = std::make_unique<VlcSession>();
  std::string reason;
  if (!LoadLibVlcApi(*libvlc_path, &session->api, &reason)) {
    Error(result.get(), reason);
    return;
  }

  const std::string plugin_arg =
      std::string("--plugin-path=") + *plugins_directory;
  const char* argv[] = {kNoVideoTitleArg, plugin_arg.c_str()};
  session->instance = session->api.libvlc_new(2, argv);
  if (session->instance == nullptr) {
    ReleaseSession(session.get());
    Error(result.get(), "libvlc_new failed.");
    return;
  }

  VlcSession* session_ptr = session.get();
  FlutterDesktopTextureInfo texture_info = {};
  texture_info.type = kFlutterDesktopPixelBufferTexture;
  texture_info.pixel_buffer_config.callback = VlcPixelBufferTextureCallback;
  texture_info.pixel_buffer_config.user_data = session_ptr;
  session->texture_id =
      FlutterDesktopTextureRegistrarRegisterExternalTexture(
          g_texture_registrar, &texture_info);
  if (session->texture_id < 0) {
    ReleaseSession(session.get());
    Error(result.get(), "Flutter VLC texture registration failed.");
    return;
  }

  const int64_t backend_id = g_next_session_id++;
  g_sessions[backend_id] = std::move(session);
  Success(result.get(),
          MapOf({{"backendId", backend_id},
                 {"textureId", g_sessions[backend_id]->texture_id}}));
}

void HandleOpenLocalFile(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto backend_id = IntArg(args, "backendId");
  const auto path = StringArg(args, "path");
  VlcSession* session = backend_id.has_value() ? SessionForId(*backend_id)
                                               : nullptr;
  if (session == nullptr || !path.has_value()) {
    Error(result.get(), "Valid backendId and path are required.");
    return;
  }
  if (session->player != nullptr) {
    session->api.libvlc_media_player_stop(session->player);
    session->api.libvlc_media_player_release(session->player);
    session->player = nullptr;
  }
  libvlc_media_t* media =
      session->api.libvlc_media_new_path(session->instance, path->c_str());
  if (media == nullptr) {
    Error(result.get(), "libvlc_media_new_path failed.");
    return;
  }
  session->player = session->api.libvlc_media_player_new_from_media(media);
  session->api.libvlc_media_release(media);
  if (session->player == nullptr) {
    Error(result.get(), "libvlc_media_player_new_from_media failed.");
    return;
  }
  session->api.libvlc_video_set_callbacks(
      session->player, VlcVideoLock, VlcVideoUnlock, VlcVideoDisplay, session);
  session->api.libvlc_video_set_format_callbacks(
      session->player, VlcVideoFormat, VlcVideoCleanup);
  Success(result.get(), MapOf({{"ok", true}}));
}

void HandleSimpleCommand(
    const std::string& method, const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto backend_id = IntArg(args, "backendId");
  VlcSession* session = backend_id.has_value() ? SessionForId(*backend_id)
                                               : nullptr;
  if (session == nullptr || session->player == nullptr) {
    Error(result.get(), "A loaded VLC backend is required.");
    return;
  }
  if (method == "play") {
    if (session->api.libvlc_media_player_play(session->player) != 0) {
      Error(result.get(), "libvlc_media_player_play failed.");
      return;
    }
  } else if (method == "pause") {
    session->api.libvlc_media_player_pause(session->player);
  } else if (method == "stop") {
    session->api.libvlc_media_player_stop(session->player);
  } else if (method == "seek") {
    const auto position_ms = IntArg(args, "positionMs");
    session->api.libvlc_media_player_set_time(
        session->player,
        static_cast<libvlc_time_t>(position_ms.value_or(0)));
  }
  Success(result.get(), MapOf({{"ok", true}}));
}

void HandleTelemetry(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto backend_id = IntArg(args, "backendId");
  VlcSession* session = backend_id.has_value() ? SessionForId(*backend_id)
                                               : nullptr;
  if (session == nullptr || session->player == nullptr) {
    Success(result.get(),
            MapOf({{"playing", false},
                   {"completed", false},
                   {"buffering", false},
                   {"positionMs", 0},
                   {"durationMs", 0},
                   {"bufferedPositionMs", 0},
                   {"failureReason", "VLC backend has no loaded media."}}));
    return;
  }
  const int64_t position =
      static_cast<int64_t>(session->api.libvlc_media_player_get_time(
          session->player));
  const int64_t duration =
      static_cast<int64_t>(session->api.libvlc_media_player_get_length(
          session->player));
  Success(result.get(),
          MapOf({{"playing",
                  session->api.libvlc_media_player_is_playing(
                      session->player) != 0},
                 {"completed", false},
                 {"buffering", false},
                 {"positionMs", position < 0 ? 0 : position},
                 {"durationMs", duration < 0 ? 0 : duration},
                 {"bufferedPositionMs", position < 0 ? 0 : position}}));
}

void HandleDispose(
    const flutter::EncodableMap& args,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto backend_id = IntArg(args, "backendId");
  if (backend_id.has_value()) {
    const auto found = g_sessions.find(*backend_id);
    if (found != g_sessions.end()) {
      ReleaseSession(found->second.get());
      g_sessions.erase(found);
    }
  }
  Success(result.get(), MapOf({{"ok", true}}));
}

void HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap* args = ArgsMap(call);
  if (args == nullptr) {
    Error(result.get(), "Method arguments must be a map.");
    return;
  }
  const std::string& method = call.method_name();
  if (method == "probeRuntime") {
    HandleProbeRuntime(*args, std::move(result));
  } else if (method == "initialize") {
    HandleInitialize(*args, std::move(result));
  } else if (method == "openLocalFile") {
    HandleOpenLocalFile(*args, std::move(result));
  } else if (method == "play" || method == "pause" || method == "seek" ||
             method == "stop") {
    HandleSimpleCommand(method, *args, std::move(result));
  } else if (method == "telemetry") {
    HandleTelemetry(*args, std::move(result));
  } else if (method == "dispose") {
    HandleDispose(*args, std::move(result));
  } else {
    result->NotImplemented();
  }
}

}  // namespace

void RegisterLibVlcFallbackBridge(flutter::FlutterEngine* engine) {
  FlutterDesktopPluginRegistrarRef registrar_ref =
      engine->GetRegistrarForPlugin("ElainaLibVlcFallbackBridge");
  g_texture_registrar =
      FlutterDesktopRegistrarGetTextureRegistrar(registrar_ref);
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      engine->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(HandleMethodCall);
  static std::vector<
      std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>>
      channels;
  channels.push_back(std::move(channel));
}
