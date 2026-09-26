#!/usr/bin/env python3
"""Print the viewable top-level windows on $DISPLAY as "<width>x<height> <title>".

Plain ctypes over libX11, so the smoke test needs no xwininfo/xdotool. There is no
window manager under Xvfb, so top-level windows are the root window's direct children.
"""
import ctypes
import ctypes.util
import sys

x11 = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
Window = ctypes.c_ulong


class XWindowAttributes(ctypes.Structure):
    _fields_ = [
        ("x", ctypes.c_int), ("y", ctypes.c_int),
        ("width", ctypes.c_int), ("height", ctypes.c_int),
        ("border_width", ctypes.c_int), ("depth", ctypes.c_int),
        ("visual", ctypes.c_void_p), ("root", Window),
        ("c_class", ctypes.c_int), ("bit_gravity", ctypes.c_int),
        ("win_gravity", ctypes.c_int), ("backing_store", ctypes.c_int),
        ("backing_planes", ctypes.c_ulong), ("backing_pixel", ctypes.c_ulong),
        ("save_under", ctypes.c_int), ("colormap", ctypes.c_ulong),
        ("map_installed", ctypes.c_int), ("map_state", ctypes.c_int),
        ("all_event_masks", ctypes.c_long), ("your_event_mask", ctypes.c_long),
        ("do_not_propagate_mask", ctypes.c_long), ("override_redirect", ctypes.c_int),
        ("screen", ctypes.c_void_p),
    ]


IS_VIEWABLE = 2

x11.XOpenDisplay.restype = ctypes.c_void_p
x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
x11.XDefaultRootWindow.restype = Window
x11.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x11.XQueryTree.argtypes = [ctypes.c_void_p, Window, ctypes.POINTER(Window), ctypes.POINTER(Window),
                           ctypes.POINTER(ctypes.POINTER(Window)), ctypes.POINTER(ctypes.c_uint)]
x11.XGetWindowAttributes.argtypes = [ctypes.c_void_p, Window, ctypes.POINTER(XWindowAttributes)]
x11.XFetchName.argtypes = [ctypes.c_void_p, Window, ctypes.POINTER(ctypes.c_char_p)]

dpy = x11.XOpenDisplay(None)
if not dpy:
    sys.exit("cannot open display")

root, parent = Window(), Window()
children, count = ctypes.POINTER(Window)(), ctypes.c_uint()
x11.XQueryTree(dpy, x11.XDefaultRootWindow(dpy), ctypes.byref(root), ctypes.byref(parent),
               ctypes.byref(children), ctypes.byref(count))

for i in range(count.value):
    win = children[i]
    attrs = XWindowAttributes()
    if not x11.XGetWindowAttributes(dpy, win, ctypes.byref(attrs)) or attrs.map_state != IS_VIEWABLE:
        continue
    name = ctypes.c_char_p()
    x11.XFetchName(dpy, win, ctypes.byref(name))
    title = name.value.decode("utf-8", "replace") if name.value else ""
    print(f"{attrs.width}x{attrs.height} {title}")
