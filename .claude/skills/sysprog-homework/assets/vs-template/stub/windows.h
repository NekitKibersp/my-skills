// Заглушка windows.h для проверки сборки на Linux (g++ -Istub). В VS не нужна.
#pragma once
#include <cstdlib>
typedef unsigned long DWORD; typedef int BOOL; typedef void* HANDLE;
inline BOOL SetConsoleCP(unsigned) { return 1; }
inline BOOL SetConsoleOutputCP(unsigned) { return 1; }
inline void Sleep(DWORD) {}
