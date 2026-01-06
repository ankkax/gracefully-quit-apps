#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    Display *dpy = XOpenDisplay(NULL);
    if (!dpy) return 1;

    Atom WM_PROTOCOLS = XInternAtom(dpy, "WM_PROTOCOLS", False);
    Atom WM_DELETE = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    Atom NET_WM_WINDOW_TYPE = XInternAtom(dpy, "_NET_WM_WINDOW_TYPE", False);
    Atom NET_WM_WINDOW_TYPE_NORMAL =
        XInternAtom(dpy, "_NET_WM_WINDOW_TYPE_NORMAL", False);

    Window root = DefaultRootWindow(dpy);
    Window parent, *children = NULL;
    unsigned int nchildren = 0;

    if (!XQueryTree(dpy, root, &root, &parent, &children, &nchildren))
        goto cleanup;

    for (unsigned int i = 0; i < nchildren; i++) {
        Window w = children[i];

        /* Skip override-redirect windows */
        XWindowAttributes attr;
        if (!XGetWindowAttributes(dpy, w, &attr) || attr.override_redirect)
            continue;

        /* Check window type == NORMAL */
        Atom actual_type;
        int actual_format;
        unsigned long nitems, bytes_after;
        Atom *types = NULL;

        if (XGetWindowProperty(dpy, w, NET_WM_WINDOW_TYPE,
                               0, 8, False, XA_ATOM,
                               &actual_type, &actual_format,
                               &nitems, &bytes_after,
                               (unsigned char **)&types) != Success)
            continue;

        int is_normal = 0;
        for (unsigned long j = 0; j < nitems; j++) {
            if (types[j] == NET_WM_WINDOW_TYPE_NORMAL) {
                is_normal = 1;
                break;
            }
        }
        if (types) XFree(types);
        if (!is_normal) continue;

        /* Check WM_DELETE_WINDOW support */
        Atom *protocols = NULL;
        int nprotocols = 0;
        int supports_delete = 0;

        if (XGetWMProtocols(dpy, w, &protocols, &nprotocols)) {
            for (int j = 0; j < nprotocols; j++) {
                if (protocols[j] == WM_DELETE) {
                    supports_delete = 1;
                    break;
                }
            }
            XFree(protocols);
        }

        if (!supports_delete)
            continue;

        /* Send WM_DELETE_WINDOW */
        XEvent ev = {0};
        ev.xclient.type = ClientMessage;
        ev.xclient.window = w;
        ev.xclient.message_type = WM_PROTOCOLS;
        ev.xclient.format = 32;
        ev.xclient.data.l[0] = WM_DELETE;
        ev.xclient.data.l[1] = CurrentTime;

        XSendEvent(dpy, w, False, NoEventMask, &ev);
    }

cleanup:
    if (children) XFree(children);
    XCloseDisplay(dpy);
    return 0;
}

