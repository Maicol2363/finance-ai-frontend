#ifndef RUNNER_LOCAL_SPEECH_BRIDGE_H_
#define RUNNER_LOCAL_SPEECH_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <string>

constexpr UINT kLocalSpeechMessage = WM_APP + 47;

// SAPI is isolated on a worker thread. The UI thread owns Flutter channels.
class LocalSpeechBridge {
 public:
  LocalSpeechBridge(flutter::BinaryMessenger* messenger, HWND window);
  ~LocalSpeechBridge();
  void Deliver(LPARAM message);
  void Pause();

 private:
  struct Worker;
  HWND window_;
  std::unique_ptr<Worker> worker_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> methods_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> events_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::string last_error_;
};

#endif
