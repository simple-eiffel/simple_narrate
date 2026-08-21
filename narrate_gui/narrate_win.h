/* ocr_cairo_win.h - pure Win32 scaffolding for the cairo face.
   v2: adds keyboard input, a frozen-desktop drag overlay (the pure-route
   replacement for the Vision2 region picker) and a screen grabber that
   BitBlts straight into a caller-supplied cairo ARGB32 buffer (the
   pure-route replacement for EV_SCREEN.sub_pixmap). */

#ifndef OCR_CAIRO_WIN_H
#define OCR_CAIRO_WIN_H

#include <windows.h>
#pragma comment(lib, "shell32.lib")

/* Event queue: [type, a, b, c] per slot.
   main window:  2 lbutton(x,y) | 3 char(code) | 4 keydown(vk) | 6 expose | 7 tick
   overlay:     12 move(x,y)   | 13 down(x,y) | 14 up(x,y)    | 15 cancel | 16 expose */
#define NW_QCAP 1024
static HWND s_nw_hwnd = 0;
static HWND s_nw_overlay = 0;
static int  s_nw_q[NW_QCAP][4];
static int  s_nw_qhead = 0, s_nw_qtail = 0;

static void nw_push(int t, int a, int b, int c) {
    int next = (s_nw_qtail + 1) % NW_QCAP;
    if (next == s_nw_qhead) return;
    s_nw_q[s_nw_qtail][0] = t;
    s_nw_q[s_nw_qtail][1] = a;
    s_nw_q[s_nw_qtail][2] = b;
    s_nw_q[s_nw_qtail][3] = c;
    s_nw_qtail = next;
}

static LRESULT CALLBACK nw_wndproc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_LBUTTONDOWN:
            SetFocus(h);
            nw_push(2, (int)(short)LOWORD(l), (int)(short)HIWORD(l), 0);
            return 0;
        case WM_CHAR:
            nw_push(3, (int)w, 0, 0);
            return 0;
        case WM_KEYDOWN:
            if (w == VK_LEFT || w == VK_RIGHT || w == VK_HOME || w == VK_END || w == VK_DELETE)
                nw_push(4, (int)w, 0, 0);
            return 0;
        case WM_TIMER:
            nw_push(7, 0, 0, 0);
            return 0;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            BeginPaint(h, &ps);
            EndPaint(h, &ps);
            nw_push(6, 0, 0, 0);
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
        case WM_DESTROY:
            KillTimer(h, 1);
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(h, m, w, l);
}

static LRESULT CALLBACK nw_overlay_proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_MOUSEMOVE:
            nw_push(12, (int)(short)LOWORD(l), (int)(short)HIWORD(l), 0);
            return 0;
        case WM_LBUTTONDOWN:
            SetCapture(h);
            nw_push(13, (int)(short)LOWORD(l), (int)(short)HIWORD(l), 0);
            return 0;
        case WM_LBUTTONUP:
            ReleaseCapture();
            nw_push(14, (int)(short)LOWORD(l), (int)(short)HIWORD(l), 0);
            return 0;
        case WM_KEYDOWN:
            if (w == VK_ESCAPE) nw_push(15, 0, 0, 0);
            return 0;
        case WM_RBUTTONDOWN:
            nw_push(15, 0, 0, 0);
            return 0;
        case WM_PAINT: {
            PAINTSTRUCT ps;
            BeginPaint(h, &ps);
            EndPaint(h, &ps);
            nw_push(16, 0, 0, 0);
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
    }
    return DefWindowProcW(h, m, w, l);
}

static void* nw_create_window(const wchar_t* title, int px, int py, int cw, int ch) {
    WNDCLASSW wc;
    RECT r;
    HWND h;
    SetProcessDPIAware();
    ZeroMemory(&wc, sizeof(wc));
    wc.lpfnWndProc = nw_wndproc;
    wc.hInstance = GetModuleHandleW(0);
    wc.hCursor = LoadCursorW(0, (LPCWSTR)IDC_ARROW);
    wc.lpszClassName = L"NarrateWindow";
    RegisterClassW(&wc);
    r.left = 0; r.top = 0; r.right = cw; r.bottom = ch;
    AdjustWindowRect(&r, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX, FALSE);
    h = CreateWindowExW(0, L"NarrateWindow", title,
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        px, py,
        r.right - r.left, r.bottom - r.top, 0, 0, GetModuleHandleW(0), 0);
    s_nw_hwnd = h;
    if (h) {
        ShowWindow(h, SW_SHOW);
        UpdateWindow(h);
        SetTimer(h, 1, 500, 0);
    }
    return (void*)h;
}

static int nw_pump(void) {
    MSG m;
    BOOL r = GetMessageW(&m, 0, 0, 0);
    if (r <= 0) return 0;
    TranslateMessage(&m);
    DispatchMessageW(&m);
    return 1;
}

static int nw_next_event(int* out4) {
    if (s_nw_qhead == s_nw_qtail) return 0;
    out4[0] = s_nw_q[s_nw_qhead][0];
    out4[1] = s_nw_q[s_nw_qhead][1];
    out4[2] = s_nw_q[s_nw_qhead][2];
    out4[3] = s_nw_q[s_nw_qhead][3];
    s_nw_qhead = (s_nw_qhead + 1) % NW_QCAP;
    return out4[0];
}

static void* nw_get_dc(void)         { return s_nw_hwnd ? (void*)GetDC(s_nw_hwnd) : 0; }
static void  nw_release_dc(void* dc) { if (s_nw_hwnd && dc) ReleaseDC(s_nw_hwnd, (HDC)dc); }

static double nw_now_ms(void) {
    LARGE_INTEGER f, c;
    QueryPerformanceFrequency(&f);
    QueryPerformanceCounter(&c);
    return (double)c.QuadPart * 1000.0 / (double)f.QuadPart;
}

static int nw_shell_open(const wchar_t* path) {
    return (int)(INT_PTR)ShellExecuteW(0, L"open", path, 0, 0, SW_SHOWNORMAL) > 32 ? 1 : 0;
}

/* ---- screen metrics (virtual desktop) ---- */
static int nw_screen_x(void) { return GetSystemMetrics(SM_XVIRTUALSCREEN); }
static int nw_screen_y(void) { return GetSystemMetrics(SM_YVIRTUALSCREEN); }
static int nw_screen_w(void) { return GetSystemMetrics(SM_CXVIRTUALSCREEN); }
static int nw_screen_h(void) { return GetSystemMetrics(SM_CYVIRTUALSCREEN); }

/* ---- pure screen grab: BitBlt the desktop region into a caller-supplied
   cairo ARGB32 buffer (bits/stride), alpha forced opaque. Replaces
   EV_SCREEN.sub_pixmap on the pure route. Returns 1 on success. ---- */
static int nw_grab_screen(int x, int y, int w, int h, void* bits, int stride) {
    HDC screen, mem;
    HBITMAP dib, old;
    BITMAPINFO bi;
    void* dib_bits = 0;
    int row, col, ok = 0;
    if (!bits || w <= 0 || h <= 0) return 0;
    screen = GetDC(0);
    if (!screen) return 0;
    mem = CreateCompatibleDC(screen);
    ZeroMemory(&bi, sizeof(bi));
    bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bi.bmiHeader.biWidth = w;
    bi.bmiHeader.biHeight = -h;               /* top-down */
    bi.bmiHeader.biPlanes = 1;
    bi.bmiHeader.biBitCount = 32;
    bi.bmiHeader.biCompression = BI_RGB;
    dib = CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &dib_bits, 0, 0);
    if (dib && dib_bits) {
        old = (HBITMAP)SelectObject(mem, dib);
        if (BitBlt(mem, 0, 0, w, h, screen, x, y, SRCCOPY | CAPTUREBLT)) {
            for (row = 0; row < h; row++) {
                unsigned int* src = (unsigned int*)((char*)dib_bits + (size_t)row * w * 4);
                unsigned int* dst = (unsigned int*)((char*)bits + (size_t)row * stride);
                for (col = 0; col < w; col++)
                    dst[col] = src[col] | 0xFF000000u;   /* opaque alpha */
            }
            ok = 1;
        }
        SelectObject(mem, old);
        DeleteObject(dib);
    }
    DeleteDC(mem);
    ReleaseDC(0, screen);
    return ok;
}

/* ---- frozen-desktop drag overlay ---- */
static void* nw_show_overlay(void) {
    WNDCLASSW wc;
    int vx = nw_screen_x(), vy = nw_screen_y();
    int vw = nw_screen_w(), vh = nw_screen_h();
    if (!s_nw_overlay) {
        ZeroMemory(&wc, sizeof(wc));
        wc.lpfnWndProc = nw_overlay_proc;
        wc.hInstance = GetModuleHandleW(0);
        wc.hCursor = LoadCursorW(0, (LPCWSTR)IDC_CROSS);
        wc.lpszClassName = L"OcrCairoOverlay";
        RegisterClassW(&wc);
        s_nw_overlay = CreateWindowExW(WS_EX_TOPMOST, L"OcrCairoOverlay", L"",
            WS_POPUP, vx, vy, vw, vh, 0, 0, GetModuleHandleW(0), 0);
    }
    if (s_nw_overlay) {
        SetWindowPos(s_nw_overlay, HWND_TOPMOST, vx, vy, vw, vh, SWP_SHOWWINDOW);
        SetForegroundWindow(s_nw_overlay);
        SetFocus(s_nw_overlay);
    }
    return (void*)s_nw_overlay;
}

static void nw_hide_overlay(void) {
    if (s_nw_overlay) ShowWindow(s_nw_overlay, SW_HIDE);
}

static void* nw_overlay_dc(void)         { return s_nw_overlay ? (void*)GetDC(s_nw_overlay) : 0; }
static void  nw_overlay_release(void* dc){ if (s_nw_overlay && dc) ReleaseDC(s_nw_overlay, (HDC)dc); }

/* ---- status strip: second topmost tool window ----
   events: 21 strip_lbutton(x,y) | 22 strip_moved(x,y) | 23 strip_expose */
static HWND s_nw_strip = 0;

static LRESULT CALLBACK nw_strip_proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    switch (m) {
        case WM_LBUTTONDOWN: {
            int x = (int)(short)LOWORD(l), y = (int)(short)HIWORD(l);
            nw_push(21, x, y, 0);
            /* drag anywhere except the transport corner (right 90px, top 26px) */
            if (!(y < 26 && x > 0)) { }
            if (y >= 26 || x < 1) {
                ReleaseCapture();
                SendMessageW(h, WM_NCLBUTTONDOWN, HTCAPTION, 0);
            }
            return 0;
        }
        case WM_EXITSIZEMOVE: {
            RECT r;
            GetWindowRect(h, &r);
            nw_push(22, r.left, r.top, 0);
            return 0;
        }
        case WM_PAINT: {
            PAINTSTRUCT ps;
            BeginPaint(h, &ps);
            EndPaint(h, &ps);
            nw_push(23, 0, 0, 0);
            return 0;
        }
        case WM_ERASEBKGND:
            return 1;
    }
    return DefWindowProcW(h, m, w, l);
}

static void* nw_show_strip(int x, int y, int w, int h) {
    WNDCLASSW wc;
    if (!s_nw_strip) {
        ZeroMemory(&wc, sizeof(wc));
        wc.lpfnWndProc = nw_strip_proc;
        wc.hInstance = GetModuleHandleW(0);
        wc.hCursor = LoadCursorW(0, (LPCWSTR)IDC_ARROW);
        wc.lpszClassName = L"NarrateAux";
        RegisterClassW(&wc);
        s_nw_strip = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
            L"NarrateAux", L"", WS_POPUP, x, y, w, h,
            0, 0, GetModuleHandleW(0), 0);
    }
    if (s_nw_strip)
        SetWindowPos(s_nw_strip, HWND_TOPMOST, x, y, w, h, SWP_SHOWWINDOW | SWP_NOACTIVATE);
    return (void*)s_nw_strip;
}

static void nw_hide_strip(void) {
    if (s_nw_strip) ShowWindow(s_nw_strip, SW_HIDE);
}

static void* nw_strip_dc(void)          { return s_nw_strip ? (void*)GetDC(s_nw_strip) : 0; }
static void  nw_strip_release(void* dc) { if (s_nw_strip && dc) ReleaseDC(s_nw_strip, (HDC)dc); }

/* ---- helpers for the run engine ---- */
static int nw_buffers_equal(const void* a, const void* b, int len) {
    return (a && b && len > 0 && memcmp(a, b, (size_t)len) == 0) ? 1 : 0;
}

static int nw_minutes_of_day(void) {
    SYSTEMTIME st;
    GetLocalTime(&st);
    return (int)st.wHour * 60 + (int)st.wMinute;
}

#endif /* OCR_CAIRO_WIN_H */

/* Private font loading: the vendored TTFs become selectable by family name
   through Cairo's Win32 font backend, process-only (FR_PRIVATE), no install. */
static int nw_add_font (const char *path) {
    return (int) AddFontResourceExA ((LPCSTR) path, FR_PRIVATE, 0);
}
