#include "local_speech_bridge.h"

#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>
#include <sapi.h>
#include <shellapi.h>
#pragma warning(push)
#pragma warning(disable : 4996)  // Deprecated helpers inside the Windows SDK.
#include <sphelper.h>
#pragma warning(pop)
#include <wrl/client.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <thread>
#include <utility>
#include <vector>

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
using Microsoft::WRL::ComPtr;

struct SpeechMessage {
  int64_t session;
  std::string type;
  std::string text;
  std::string code;
};

enum class Action { prepare, start, stop, cancel, interrupt, quit };
struct Command {
  Action action;
  int64_t session;
  std::string language;
};

int64_t Integer(const EncodableValue& value) {
  if (const auto* integer = std::get_if<int32_t>(&value)) return *integer;
  if (const auto* integer = std::get_if<int64_t>(&value)) return *integer;
  return 0;
}

std::string Utf8(const wchar_t* words) {
  if (!words) return {};
  const int length = static_cast<int>(wcslen(words));
  if (length == 0) return {};
  const int bytes = ::WideCharToMultiByte(CP_UTF8, 0, words, length, nullptr, 0,
                                         nullptr, nullptr);
  if (bytes <= 0) return {};
  std::string text(static_cast<size_t>(bytes), '\0');
  ::WideCharToMultiByte(CP_UTF8, 0, words, length, text.data(), bytes,
                        nullptr, nullptr);
  return text;
}

// Restrict recognition to the installed Microsoft Desktop SAPI engine. A TTS
// voice, OneCore token, arbitrary provider, or shared/online recognizer is not
// silently substituted for a missing local recognizer.
bool LocalToken(ISpObjectToken* token, LANGID wanted, bool* exact) {
  wchar_t* id = nullptr;
  if (FAILED(token->GetId(&id)) || !id) return false;
  constexpr wchar_t prefix[] =
      L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\Recognizers\\Tokens\\MS-";
  const bool local = _wcsnicmp(id, prefix, wcslen(prefix)) == 0 &&
      wcsstr(id, L"-DESK") != nullptr;
  ::CoTaskMemFree(id);
  if (!local) return false;
  ComPtr<ISpDataKey> attributes;
  if (FAILED(token->OpenKey(L"Attributes", &attributes))) return false;
  wchar_t* vendor = nullptr;
  if (FAILED(attributes->GetStringValue(L"Vendor", &vendor))) return false;
  const bool microsoft = vendor && _wcsicmp(vendor, L"Microsoft") == 0;
  ::CoTaskMemFree(vendor);
  if (!microsoft) return false;
  wchar_t* languages = nullptr;
  if (FAILED(attributes->GetStringValue(L"Language", &languages)) || !languages)
    return false;
  bool match = false;
  const wchar_t* cursor = languages;
  while (*cursor) {
    wchar_t* end = nullptr;
    const unsigned long value = wcstoul(cursor, &end, 16);
    if (end == cursor) break;
    if (value <= 0xffff && PRIMARYLANGID(static_cast<LANGID>(value)) ==
        PRIMARYLANGID(wanted)) {
      match = true;
      if (value == wanted) *exact = true;
    }
    cursor = *end == L';' ? end + 1 : end;
    if (*cursor != L';' && *cursor && cursor == end) break;
  }
  ::CoTaskMemFree(languages);
  return match;
}
}  // namespace

struct LocalSpeechBridge::Worker {
  explicit Worker(HWND window) : window_(window) {
    wake_ = ::CreateEventW(nullptr, FALSE, FALSE, nullptr);
    if (wake_) {
      try { thread_ = std::thread([this]() { Run(); }); }
      catch (...) { ::CloseHandle(wake_); wake_ = nullptr; }
    }
  }
  ~Worker() {
    if (thread_.joinable()) { Queue({Action::quit, 0, {}}); thread_.join(); }
    if (wake_) ::CloseHandle(wake_);
  }

  void Queue(Command command) {
    if (command.action == Action::start) {
      desired_capture_.store(command.session);
    } else if (command.action == Action::prepare || command.action == Action::interrupt ||
               command.action == Action::quit ||
               ((command.action == Action::stop || command.action == Action::cancel) &&
                (command.session == 0 || desired_capture_.load() == command.session))) {
      desired_capture_.store(0);
    }
    if (!wake_) {
      Emit(command.session, "error", {}, "speech_offline_unavailable");
      return;
    }
    { std::lock_guard<std::mutex> lock(mutex_); commands_.push_back(std::move(command)); }
    ::SetEvent(wake_);
  }

  void Emit(int64_t session, const std::string& type, const std::string& text = {},
            const std::string& code = {}) {
    auto message = std::make_unique<SpeechMessage>(SpeechMessage{session, type, text, code});
    if (::PostMessageW(window_, kLocalSpeechMessage, 0,
                       reinterpret_cast<LPARAM>(message.get()))) message.release();
  }

  void Close(bool purge) {
    active_ = false; finishing_ = false;
    if (recognizer_) recognizer_->SetRecoState(purge ? SPRST_INACTIVE_WITH_PURGE : SPRST_INACTIVE);
    if (grammar_) grammar_->SetDictationState(SPRS_INACTIVE);
    if (context_) context_->SetContextState(SPCS_DISABLED);
  }

  void Error(const std::string& code) {
    Close(true); prepared_ = false;
    Emit(session_, "error", {}, code);
  }

  HRESULT CreateContext() {
    grammar_.Reset(); context_.Reset();
    HRESULT hr = recognizer_->CreateRecoContext(&context_);
    if (SUCCEEDED(hr)) hr = context_->SetContextState(SPCS_DISABLED);
    if (SUCCEEDED(hr)) hr = context_->SetNotifyWin32Event();
    const ULONGLONG interest = SPFEI(SPEI_HYPOTHESIS) | SPFEI(SPEI_RECOGNITION) |
        SPFEI(SPEI_END_SR_STREAM) | SPFEI(SPEI_FALSE_RECOGNITION);
    if (SUCCEEDED(hr)) hr = context_->SetInterest(interest, interest);
    if (SUCCEEDED(hr)) hr = context_->CreateGrammar(1, &grammar_);
    if (SUCCEEDED(hr)) hr = grammar_->LoadDictation(nullptr, SPLO_STATIC);
    return hr;
  }

  void Prepare(const Command& command, bool com_ready) {
    Close(true); Drain(false);
    session_ = command.session;
    if (!com_ready) { Error("speech_offline_unavailable"); return; }
    if (prepared_ && language_ == command.language && recognizer_) {
      Emit(session_, "ready"); return;
    }
    prepared_ = false; grammar_.Reset(); context_.Reset(); recognizer_.Reset();
    language_ = command.language;
    ComPtr<IEnumSpObjectTokens> tokens;
    HRESULT hr = ::SpEnumTokens(SPCAT_RECOGNIZERS, nullptr, nullptr, &tokens);
    if (FAILED(hr)) { Error("speech_offline_unavailable"); return; }
    ComPtr<ISpObjectToken> selected, candidate;
    const LANGID wanted = language_ == "en-US" ? 0x0409 : 0x0c0a;
    while (tokens->Next(1, &candidate, nullptr) == S_OK) {
      bool exact = false;
      if (LocalToken(candidate.Get(), wanted, &exact)) {
        selected = candidate;
        if (exact) break;
      }
      candidate.Reset();
    }
    if (!selected) { Error("speech_language_unavailable"); return; }
    hr = ::CoCreateInstance(CLSID_SpInprocRecognizer, nullptr, CLSCTX_INPROC_SERVER,
                            IID_PPV_ARGS(&recognizer_));
    if (SUCCEEDED(hr)) hr = recognizer_->SetRecognizer(selected.Get());
    if (SUCCEEDED(hr)) hr = recognizer_->SetRecoState(SPRST_INACTIVE);
    if (SUCCEEDED(hr)) hr = CreateContext();
    if (FAILED(hr)) { Error("speech_offline_unavailable"); return; }
    prepared_ = true; Emit(session_, "ready");
  }

  void Start(const Command& command) {
    if (!prepared_ || language_ != command.language) {
      session_ = command.session; Error("speech_language_unavailable"); return;
    }
    Close(true); Drain(false); session_ = command.session;
    committed_.clear(); partial_.clear();
    // Keep the expensive recognizer warmed, but isolate each capture's result
    // context so a cancelled stream cannot deliver words into the next session.
    HRESULT hr = CreateContext();
    if (FAILED(hr)) { Error("speech_provider_error"); return; }
    ComPtr<ISpAudio> audio;
    hr = ::SpCreateDefaultObjectFromCategoryId(SPCAT_AUDIOIN, audio.GetAddressOf());
    if (SUCCEEDED(hr)) hr = recognizer_->SetInput(audio.Get(), TRUE);
    // Stop/cancel update intent on the UI thread, even if engine startup is
    // still running. A released button must not arm the microphone later.
    if (desired_capture_.load() != command.session) {
      Close(true); Emit(session_, "final"); return;
    }
    if (SUCCEEDED(hr)) hr = context_->SetContextState(SPCS_ENABLED);
    if (SUCCEEDED(hr)) hr = grammar_->SetDictationState(SPRS_ACTIVE);
    if (SUCCEEDED(hr)) hr = recognizer_->SetRecoState(SPRST_ACTIVE);
    if (FAILED(hr)) { Error(hr == E_ACCESSDENIED ? "speech_permission_denied" : "speech_microphone_busy"); return; }
    if (desired_capture_.load() != command.session) {
      Close(true); Emit(session_, "final"); return;
    }
    active_ = true; Emit(session_, "listening");
  }

  std::string ResultText(ISpRecoResult* result) {
    wchar_t* words = nullptr;
    const ULONG whole = static_cast<ULONG>(SP_GETWHOLEPHRASE);
    if (!result || FAILED(result->GetText(whole, whole,
                                          TRUE, &words, nullptr))) return {};
    std::string text = Utf8(words); ::CoTaskMemFree(words); return text;
  }

  void Drain(bool deliver) {
    if (!context_) return;
    SPEVENT event{}; ULONG fetched = 0;
    while (context_->GetEvents(1, &event, &fetched) == S_OK && fetched == 1) {
      if (deliver && (active_ || finishing_)) {
        if (event.eEventId == SPEI_HYPOTHESIS || event.eEventId == SPEI_RECOGNITION) {
          const auto text = ResultText(reinterpret_cast<ISpRecoResult*>(event.lParam));
          if (event.eEventId == SPEI_RECOGNITION) {
            if (!committed_.empty() && !text.empty()) committed_ += " ";
            committed_ += text; partial_.clear();
          } else partial_ = text;
          const auto full = committed_ + (committed_.empty() || partial_.empty() ? "" : " ") + partial_;
          if (full.size() > 8192) Error("speech_text_too_long");
          else Emit(session_, "partial", full);
        } else if (event.eEventId == SPEI_END_SR_STREAM) {
          if (FAILED(static_cast<HRESULT>(event.lParam))) Error("speech_provider_error");
          else if (finishing_) {
            if (!partial_.empty()) Error("speech_no_match");
            else { Close(false); Emit(session_, "final", committed_); }
          } else Error("speech_session_ended");
        }
      }
      ::SpClearEvent(&event); event = {};
    }
  }

  void Run() {
    const HRESULT com = ::CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    bool running = true;
    while (running) {
      std::vector<Command> commands;
      { std::lock_guard<std::mutex> lock(mutex_); commands.swap(commands_); }
      for (const auto& command : commands) {
        switch (command.action) {
          case Action::prepare: Prepare(command, SUCCEEDED(com)); break;
          case Action::start: Start(command); break;
          case Action::stop:
            if (command.session == session_ && active_) {
              active_ = false; finishing_ = true;
              // INACTIVE closes the audio device, then finishes buffered words.
              if (FAILED(recognizer_->SetRecoState(SPRST_INACTIVE))) Error("speech_provider_error");
            }
            break;
          case Action::cancel:
            if (command.session == 0 || command.session == session_) { Close(true); Drain(false); }
            break;
          case Action::interrupt:
            if (active_ || finishing_) Error("speech_session_ended");
            break;
          case Action::quit: Close(true); running = false; break;
        }
      }
      if (!running) break;
      Drain(true);
      HANDLE handles[] = {wake_, context_ ? context_->GetNotifyEventHandle() : nullptr};
      const DWORD count = handles[1] && handles[1] != INVALID_HANDLE_VALUE ? 2 : 1;
      ::WaitForMultipleObjects(count, handles, FALSE, INFINITE);
    }
    grammar_.Reset(); context_.Reset(); recognizer_.Reset();
    if (SUCCEEDED(com)) ::CoUninitialize();
  }

  HWND window_;
  HANDLE wake_ = nullptr;
  std::thread thread_;
  std::mutex mutex_;
  std::vector<Command> commands_;
  std::atomic<int64_t> desired_capture_{0};
  ComPtr<ISpRecognizer> recognizer_;
  ComPtr<ISpRecoContext> context_;
  ComPtr<ISpRecoGrammar> grammar_;
  int64_t session_ = 0;
  bool prepared_ = false, active_ = false, finishing_ = false;
  std::string language_, committed_, partial_;
};

LocalSpeechBridge::LocalSpeechBridge(flutter::BinaryMessenger* messenger, HWND window)
    : window_(window), worker_(std::make_unique<Worker>(window)) {
  methods_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      messenger, "finance_ai/speech", &flutter::StandardMethodCodec::GetInstance());
  events_ = std::make_unique<flutter::EventChannel<EncodableValue>>(
      messenger, "finance_ai/speech/events", &flutter::StandardMethodCodec::GetInstance());
  events_->SetStreamHandler(std::make_unique<flutter::StreamHandlerFunctions<EncodableValue>>(
      [this](const EncodableValue*, std::unique_ptr<flutter::EventSink<EncodableValue>>&& events) {
        sink_ = std::move(events); return nullptr;
      },
      [this](const EncodableValue*) {
        sink_.reset(); worker_->Queue({Action::cancel, 0, {}}); return nullptr;
      }));
  methods_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() == "initialize") { result->Success(); return; }
    if (call.method_name() == "settings") {
      const auto uri = last_error_.find("permission") != std::string::npos ||
          last_error_ == "speech_microphone_busy"
          ? L"ms-settings:privacy-microphone" : L"ms-settings:speech";
      const auto opened = reinterpret_cast<INT_PTR>(::ShellExecuteW(window_, L"open", uri,
          nullptr, nullptr, SW_SHOWNORMAL));
      if (opened <= 32) result->Error("speech_settings_unavailable"); else result->Success();
      return;
    }
    const auto* arguments = call.arguments() ? std::get_if<EncodableMap>(call.arguments()) : nullptr;
    int64_t session = 0; std::string language;
    if (arguments) {
      const auto id = arguments->find(EncodableValue("session"));
      if (id != arguments->end()) session = Integer(id->second);
      const auto lang = arguments->find(EncodableValue("language"));
      if (lang != arguments->end()) {
        if (const auto* value = std::get_if<std::string>(&lang->second)) language = *value;
      }
    }
    const auto& method = call.method_name();
    if (session <= 0 || ((method == "prepare" || method == "start" || method == "download") &&
        language != "es-ES" && language != "en-US")) {
      result->Error("speech_provider_error"); return;
    }
    if (method == "prepare") worker_->Queue({Action::prepare, session, language});
    else if (method == "start") worker_->Queue({Action::start, session, language});
    else if (method == "stop") worker_->Queue({Action::stop, session, {}});
    else if (method == "cancel") worker_->Queue({Action::cancel, session, {}});
    else if (method == "download") { result->Error("speech_language_unavailable"); return; }
    else { result->NotImplemented(); return; }
    result->Success();
  });
}

LocalSpeechBridge::~LocalSpeechBridge() {
  methods_->SetMethodCallHandler(nullptr); events_->SetStreamHandler(nullptr);
  sink_.reset(); worker_.reset();
  MSG message{};
  while (::PeekMessageW(&message, window_, kLocalSpeechMessage, kLocalSpeechMessage, PM_REMOVE)) {
    delete reinterpret_cast<SpeechMessage*>(message.lParam);
  }
}

void LocalSpeechBridge::Deliver(LPARAM pointer) {
  std::unique_ptr<SpeechMessage> message(reinterpret_cast<SpeechMessage*>(pointer));
  if (message->type == "error") last_error_ = message->code;
  if (sink_) sink_->Success(EncodableValue(EncodableMap{
      {EncodableValue("session"), EncodableValue(message->session)},
      {EncodableValue("type"), EncodableValue(message->type)},
      {EncodableValue("text"), EncodableValue(message->text)},
      {EncodableValue("code"), EncodableValue(message->code)},
      {EncodableValue("canDownload"), EncodableValue(false)},
  }));
}

void LocalSpeechBridge::Pause() { worker_->Queue({Action::interrupt, 0, {}}); }
