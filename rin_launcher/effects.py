"""窗口材质与桌面挂件相关的系统调用。

两件事：

* **小窗亚克力** —— 小窗是个普通 ``QtQuick.Window``，不是 RinUI 窗口，够不到
  RinUI 的 backdrop 机制，所以在这里直接用 DWM 给它上亚克力：Win11 22H2+ 走
  ``DWMWA_SYSTEMBACKDROP_TYPE``，Win10 退回 ``SetWindowCompositionAttribute``。
* **无焦点置顶** —— 桌面挂件不该抢焦点，也不能进任务栏。

非 Windows 上全部是安全的空操作（返回 ``False``），界面退回半透明卡片，功能
不受影响。
"""

from __future__ import annotations

import ctypes
import logging
import sys
from typing import Any

logger = logging.getLogger(__name__)

# ── DWM 属性 ─────────────────────────────────────────────────────────
DWMWA_USE_IMMERSIVE_DARK_MODE = 20
DWMWA_WINDOW_CORNER_PREFERENCE = 33
DWMWA_SYSTEMBACKDROP_TYPE = 38
DWMWA_MICA_EFFECT = 1029          # Win11 21H2 的旧接口
DWMWA_BORDER_COLOR = 34

DWMSBT_MAINWINDOW = 2             # 云母
DWMSBT_TRANSIENTWINDOW = 3        # 亚克力
DWMSBT_TABBEDWINDOW = 4           # 增强云母

DWMCP_ROUND = 2                   # 圆角窗口

ACCENT_DISABLED = 0
ACCENT_ENABLE_ACRYLICBLURBEHIND = 4
WCA_ACCENT_POLICY = 19


class _AccentPolicy(ctypes.Structure):
    _fields_ = [
        ("AccentState", ctypes.c_uint),
        ("AccentFlags", ctypes.c_uint),
        ("GradientColor", ctypes.c_uint),
        ("AnimationId", ctypes.c_uint),
    ]


class _WinCompositionAttrData(ctypes.Structure):
    _fields_ = [
        ("Attribute", ctypes.c_int),
        ("Data", ctypes.c_void_p),
        ("SizeOfData", ctypes.c_size_t),
    ]


def _hwnd(window: Any) -> int:
    """拿到原生窗口句柄；窗口还没建出来时返回 0。"""
    try:
        return int(window.winId())
    except Exception:  # 窗口已销毁 / 平台不支持
        return 0


def _set_dwm_int(hwnd: int, attribute: int, value: int) -> bool:
    try:
        dwm = ctypes.windll.dwmapi
        data = ctypes.c_int(value)
        result = dwm.DwmSetWindowAttribute(
            hwnd, attribute, ctypes.byref(data), ctypes.sizeof(data))
        return result == 0
    except Exception:
        logger.debug("DwmSetWindowAttribute(%s) failed", attribute, exc_info=True)
        return False


def _extend_frame(hwnd: int) -> None:
    """让 DWM 在客户区里绘制材质，少了这一步亚克力不会出现。"""
    try:
        class _Margins(ctypes.Structure):
            _fields_ = [("cxLeftWidth", ctypes.c_int), ("cxRightWidth", ctypes.c_int),
                        ("cyTopHeight", ctypes.c_int), ("cyBottomHeight", ctypes.c_int)]

        margins = _Margins(-1, -1, -1, -1)
        ctypes.windll.dwmapi.DwmExtendFrameIntoClientArea(hwnd, ctypes.byref(margins))
    except Exception:
        logger.debug("DwmExtendFrameIntoClientArea failed", exc_info=True)


def _apply_accent_policy(hwnd: int, gradient_color: int) -> bool:
    """Win10 那条老路：SetWindowCompositionAttribute + 亚克力。"""
    try:
        policy = _AccentPolicy(
            AccentState=ACCENT_ENABLE_ACRYLICBLURBEHIND,
            AccentFlags=2,
            GradientColor=gradient_color,
            AnimationId=0,
        )
        data = _WinCompositionAttrData(
            Attribute=WCA_ACCENT_POLICY,
            Data=ctypes.cast(ctypes.pointer(policy), ctypes.c_void_p),
            SizeOfData=ctypes.sizeof(policy),
        )
        ctypes.windll.user32.SetWindowCompositionAttribute(hwnd, ctypes.byref(data))
        return True
    except Exception:
        logger.debug("SetWindowCompositionAttribute failed", exc_info=True)
        return False


def _remove_accent_policy(hwnd: int) -> None:
    try:
        policy = _AccentPolicy(AccentState=ACCENT_DISABLED, AccentFlags=0,
                               GradientColor=0, AnimationId=0)
        data = _WinCompositionAttrData(
            Attribute=WCA_ACCENT_POLICY,
            Data=ctypes.cast(ctypes.pointer(policy), ctypes.c_void_p),
            SizeOfData=ctypes.sizeof(policy),
        )
        ctypes.windll.user32.SetWindowCompositionAttribute(hwnd, ctypes.byref(data))
    except Exception:
        logger.debug("Removing accent policy failed", exc_info=True)


def apply_acrylic(window: Any, *, dark: bool = False, tint: int = 0x99000000) -> bool:
    """给窗口铺一层亚克力。

    ``tint`` 是 ARGB 的染色值（``0xAARRGGBB``）。成功返回 ``True``，调用方据此
    决定卡片要不要画成接近透明；失败就让 QML 那层半透明背景兜底。
    """
    if sys.platform != "win32":
        return False
    hwnd = _hwnd(window)
    if not hwnd:
        return False

    _set_dwm_int(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, 1 if dark else 0)
    _set_dwm_int(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, DWMCP_ROUND)
    # 去掉 DWM 自己那条描边，卡片边框由 QML 画。
    _set_dwm_int(hwnd, DWMWA_BORDER_COLOR, 0xFFFFFFFE)

    applied = False
    if _set_dwm_int(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TRANSIENTWINDOW):
        applied = True
    elif _set_dwm_int(hwnd, DWMWA_MICA_EFFECT, 1):
        # 21H2 只有云母可用，凑合当材质用，总比纯色好。
        applied = True
    else:
        applied = _apply_accent_policy(hwnd, ctypes.c_uint(tint).value)

    if applied:
        _extend_frame(hwnd)
        logger.info("Acrylic applied to window %s", hwnd)
    return applied


def clear_acrylic(window: Any) -> None:
    """撤掉亚克力，退回普通窗口。"""
    if sys.platform != "win32":
        return
    hwnd = _hwnd(window)
    if not hwnd:
        return
    _set_dwm_int(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, 0)
    _remove_accent_policy(hwnd)


def apply_no_focus_tool_window(window: Any) -> None:
    """把窗口调成「置顶、不进任务栏、不抢焦点」的桌面挂件。

    ``WS_EX_NOACTIVATE`` 是关键：鼠标点得动，但窗口不会变成前台窗口，也不会把
    用户正在打字的目标窗口挤下去。
    """
    if sys.platform != "win32":
        return
    hwnd = _hwnd(window)
    if not hwnd:
        return
    try:
        user32 = ctypes.windll.user32
        GWL_EXSTYLE = -20
        WS_EX_NOACTIVATE = 0x08000000
        WS_EX_TOOLWINDOW = 0x00000080
        style = user32.GetWindowLongPtrW(hwnd, GWL_EXSTYLE)
        user32.SetWindowLongPtrW(
            hwnd, GWL_EXSTYLE, style | WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW)
    except Exception:
        logger.debug("Failed to set no-activate window style", exc_info=True)
