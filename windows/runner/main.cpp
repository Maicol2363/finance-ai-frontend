#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <array>
#include <filesystem>

#include "flutter_window.h"
#include "utils.h"

namespace {

constexpr wchar_t kApplicationTitle[] = L"Finance AI";
constexpr wchar_t kSingleInstanceMutex[] =
    L"Local\\FinanceAI.Desktop.SingleInstance";

void ShowStartupError(const wchar_t* code, const wchar_t* reason) {
  std::wstring message = L"Finance AI could not start.\n\nError code: ";
  message += code;
  message += L"\nTechnical reason: ";
  message += reason;
  message +=
      L"\n\nKeep this message so it can be copied into a development report.";
  ::MessageBoxW(nullptr, message.c_str(), L"Finance AI startup error",
                MB_OK | MB_ICONERROR);
}

bool PrepareBundleDirectory() {
  std::array<wchar_t, 32768> executable_path{};
  const DWORD length = ::GetModuleFileNameW(
      nullptr, executable_path.data(),
      static_cast<DWORD>(executable_path.size()));
  if (length == 0 || length >= executable_path.size()) {
    return false;
  }

  const std::filesystem::path executable_directory =
      std::filesystem::path(executable_path.data()).parent_path();
  if (!::SetCurrentDirectoryW(executable_directory.c_str())) {
    return false;
  }

  const DWORD data_attributes =
      ::GetFileAttributesW(L"data\\flutter_assets");
  const DWORD engine_attributes = ::GetFileAttributesW(L"flutter_windows.dll");
  return data_attributes != INVALID_FILE_ATTRIBUTES &&
         (data_attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 &&
         engine_attributes != INVALID_FILE_ATTRIBUTES &&
         (engine_attributes & FILE_ATTRIBUTE_DIRECTORY) == 0;
}

void FocusExistingWindow() {
  HWND existing_window = ::FindWindowW(nullptr, kApplicationTitle);
  if (existing_window == nullptr) {
    return;
  }
  if (::IsIconic(existing_window)) {
    ::ShowWindow(existing_window, SW_RESTORE);
  } else {
    ::ShowWindow(existing_window, SW_SHOW);
  }
  ::SetForegroundWindow(existing_window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  HANDLE single_instance =
      ::CreateMutexW(nullptr, FALSE, kSingleInstanceMutex);
  if (single_instance == nullptr) {
    ShowStartupError(L"windows_single_instance_unavailable",
                     L"single_instance_mutex_creation_failed");
    return EXIT_FAILURE;
  }
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    FocusExistingWindow();
    ::CloseHandle(single_instance);
    return EXIT_SUCCESS;
  }

  if (!PrepareBundleDirectory()) {
    ShowStartupError(
        L"windows_bundle_incomplete",
        L"required_data_or_flutter_engine_files_are_missing");
    ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  const HRESULT com_result =
      ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  if (FAILED(com_result) && com_result != RPC_E_CHANGED_MODE) {
    ShowStartupError(L"windows_com_initialization_failed",
                     L"com_apartment_initialization_failed");
    ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(kApplicationTitle, origin, size)) {
    ShowStartupError(L"windows_window_creation_failed",
                     L"flutter_window_or_engine_initialization_failed");
    if (SUCCEEDED(com_result)) {
      ::CoUninitialize();
    }
    ::CloseHandle(single_instance);
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (SUCCEEDED(com_result)) {
    ::CoUninitialize();
  }
  ::CloseHandle(single_instance);
  return EXIT_SUCCESS;
}
