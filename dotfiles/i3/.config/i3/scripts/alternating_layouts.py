#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import i3ipc


def find_parent(i3, window_id):
    def finder(con, parent):
        if con.id == window_id:
            return parent
        for node in con.nodes:
            res = finder(node, con)
            if res:
                return res
        return None

    return finder(i3.get_tree(), None)


def set_layout(i3, e):
    win = i3.get_tree().find_focused()
    parent = find_parent(i3, win.id)

    if parent and parent.layout != "tabbed" and parent.layout != "stacked":

        if win.rect.height > win.rect.width:
            if parent.orientation == "horizontal":
                i3.command("split v")
        else:
            if parent.orientation == "vertical":
                i3.command("split h")


def main():
    i3 = i3ipc.Connection()
    i3.on(i3ipc.Event.WINDOW_FOCUS, set_layout)
    i3.main()


if __name__ == "__main__":
    main()
