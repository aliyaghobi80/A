#ifndef RUNNER_STARTUP_LOG_H_
#define RUNNER_STARTUP_LOG_H_

#include <windows.h>
#include <filesystem>
#include <fstream>

inline void LogStartup(const char* message) {
  // Diagnostics must remain writable when installed below Program Files.
  wchar_t local_app_data[32768];
  DWORD length = GetEnvironmentVariableW(L"LOCALAPPDATA", local_app_data, 32768);
  if (length == 0 || length >= 32768) return;
  try {
    const auto directory = std::filesystem::path(local_app_data) /
                           L"MarkaziSystemChecker" / L"logs";
    std::filesystem::create_directories(directory);
    std::ofstream log(directory / L"startup.log", std::ios::app);
    SYSTEMTIME now;
    GetLocalTime(&now);
    log << now.wYear << '-' << now.wMonth << '-' << now.wDay << ' '
        << now.wHour << ':' << now.wMinute << ':' << now.wSecond << " "
        << message << '\n';
  } catch (...) {
    // Logging cannot prevent startup.
  }
}
#endif
