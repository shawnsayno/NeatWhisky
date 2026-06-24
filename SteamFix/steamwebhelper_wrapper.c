#include <windows.h>
#include <wchar.h>
#include <stdlib.h>
#include <string.h>

/*
 * steamwebhelper.exe wrapper.
 * Re-launches the real binary (steamwebhelper_orig.exe in the same dir) with
 * CEF flags --disable-gpu --single-process appended (fixes CEF 126 black-window
 * bug under Wine).
 *
 * The child is placed in a Job Object with KILL_ON_JOB_CLOSE so that when Steam
 * terminates this wrapper process, the real child dies with it. Without this the
 * child is orphaned on shutdown/restart, which makes Steam think the UI crashed
 * and relaunch it in a loop.
 */

static const wchar_t *EXTRA_ARGS = L" --disable-gpu --single-process";
static const wchar_t *ORIG_NAME  = L"steamwebhelper_orig.exe";

static wchar_t *skip_argv0(wchar_t *cmd)
{
    wchar_t *p = cmd;
    if (*p == L'"') {
        p++;
        while (*p && *p != L'"') p++;
        if (*p == L'"') p++;
    } else {
        while (*p && *p != L' ' && *p != L'\t') p++;
    }
    while (*p == L' ' || *p == L'\t') p++;
    return p;
}

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE hPrev, LPWSTR lpCmdLine, int nShow)
{
    (void)hInst; (void)hPrev; (void)lpCmdLine; (void)nShow;

    wchar_t modPath[MAX_PATH];
    DWORD n = GetModuleFileNameW(NULL, modPath, MAX_PATH);
    if (n == 0 || n >= MAX_PATH) return 1;

    wchar_t dir[MAX_PATH];
    wcscpy(dir, modPath);
    wchar_t *slash = wcsrchr(dir, L'\\');
    if (slash) *(slash + 1) = L'\0';
    else dir[0] = L'\0';

    wchar_t origPath[MAX_PATH];
    _snwprintf(origPath, MAX_PATH, L"%s%s", dir, ORIG_NAME);

    wchar_t *fullCmd = GetCommandLineW();
    wchar_t *args = skip_argv0(fullCmd);

    size_t len = wcslen(origPath) + wcslen(args) + wcslen(EXTRA_ARGS) + 8;
    wchar_t *newCmd = (wchar_t *)malloc(len * sizeof(wchar_t));
    if (!newCmd) return 1;
    _snwprintf(newCmd, len, L"\"%s\" %s%s", origPath, args, EXTRA_ARGS);

    /* job object: kill child when this wrapper (the last handle holder) dies */
    HANDLE job = CreateJobObjectW(NULL, NULL);
    if (job) {
        JOBOBJECT_EXTENDED_LIMIT_INFORMATION jeli;
        ZeroMemory(&jeli, sizeof(jeli));
        jeli.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        SetInformationJobObject(job, JobObjectExtendedLimitInformation, &jeli, sizeof(jeli));
    }

    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(origPath, newCmd, NULL, NULL, TRUE,
                        CREATE_SUSPENDED, NULL, NULL, &si, &pi)) {
        free(newCmd);
        return (int)GetLastError();
    }

    if (job) AssignProcessToJobObject(job, pi.hProcess);
    ResumeThread(pi.hThread);

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD code = 0;
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    if (job) CloseHandle(job);
    free(newCmd);
    return (int)code;
}
