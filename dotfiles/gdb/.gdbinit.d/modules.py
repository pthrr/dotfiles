import gdb
import math


def num_log10(num):
    if num <= 1:
        log10 = 1
    else:
        log10 = int(math.log10(num) + 1)
    return log10


def list_len_log10(ls):
    return num_log10(len(ls) - 1)


class Breakpoints(Dashboard.Module):
    Names = {
        gdb.BP_BREAKPOINT: "break",
        gdb.BP_WATCHPOINT: "watch",
        gdb.BP_HARDWARE_WATCHPOINT: "write watch",
        gdb.BP_READ_WATCHPOINT: "read watch",
        gdb.BP_ACCESS_WATCHPOINT: "access watch",
    }

    PendingStr = "<PENDING>"

    def __init__(self):
        self.breakpoints = []
        self.null_str = "{0:^18s}".format("(NULL)")

    def label(self):
        return "Breakpoints"

    def lines(self, term_width, term_height, style_changed):
        breakpoints = fetch_breakpoints(watchpoints=True, pending=True)
        if breakpoints is None or len(breakpoints) == 0:
            return []
        out = []

        ids = []
        hits = []
        for b in breakpoints:
            ids.append(b["number"])
            hits.append(b["hit_count"])

        log10 = num_log10(max(ids))
        hits_log10 = num_log10(max(hits))

        if self.highlighted:
            for b in breakpoints:
                out.append(self.line_highlight(b, log10, hits_log10))
        else:
            for b in breakpoints:
                out.append(self.line_nohighlight(b, log10, hits_log10))
        return out

    def line_highlight(self, b, log10, hits_log10):
        expr = b["type"] != gdb.BP_BREAKPOINT

        numstr, hitsstr, tempstr, typestr = self.line(b, log10, hits_log10)

        if b["enabled"] and not b["pending"]:
            tempstr = ansi(tempstr, R.style_selected_2)

            s = "[{0}]  ({1})".format(ansi(numstr, R.style_selected_1), tempstr)

            typestr = "  {0:12}".format(typestr)
            typestr = ansi(typestr, R.style_selected_2)
            s += typestr

            hitsstr = ansi(hitsstr, R.style_selected_2)

            addr, locationstr = self.location_highlight(b, expr)

            s += "  hits: {0}  {1}  {2}".format(hitsstr, addr, locationstr)

        else:
            if b["pending"]:
                addr = self.null_str
                locationstr = Breakpoints.PendingStr
            else:
                addr, locationstr = self.location_nohighlight(b, expr)

            s = "[{0}]  ({1})  {2:12}  hits: {3}  {4}  {5}".format(
                numstr, tempstr, typestr, hitsstr, addr, locationstr
            )
            s = ansi(s, R.style_low)

        return s

    def line_nohighlight(self, b, log10, hits_log10):
        expr = b["type"] != gdb.BP_BREAKPOINT

        numstr, hitsstr, tempstr, typestr = self.line(b, log10, hits_log10)

        if b["pending"]:
            addr = self.null_str
            locationstr = Breakpoints.PendingStr
        else:
            addr, locationstr = self.location_nohighlight(b, expr)

        if b["enabled"]:
            enabledstr = "enabled"
        else:
            enabledstr = "disabled"

        return "{0:8} [{1}]  ({2})  {3:12}  hits: {4}  {5}  {6}".format(
            enabledstr, numstr, tempstr, typestr, hitsstr, addr, locationstr
        )

    def line(self, b, log10, hits_log10):
        numstr = "{0:{width}}".format(b["number"], width=log10)

        hitsstr = "{0:{width}}".format(b["hit_count"], width=hits_log10)

        if b["temporary"]:
            tempstr = "T"
        else:
            tempstr = " "

        typestr = Breakpoints.Names[b["type"]]

        return numstr, hitsstr, tempstr, typestr

    def location_highlight(self, b, expr):
        if expr:
            sym, addr = self.location_watch(b)
            locationstr = ansi(sym.print_name, R.style_selected_1) + " at "
            line = ansi("{0}".format(sym.line), R.style_selected_1)
            src = ansi(
                "{0}".format(os.path.relpath(sym.symtab.filename)), R.style_selected_1
            )
            locationstr += src + ":" + line
        else:
            sym, addr = self.location_break(b)
            line = ansi("{0}".format(sym.line), R.style_selected_1)
            filename = sym.symtab.filename if sym and sym.symtab else "<unknown>"
            src = ansi("{0}".format(os.path.relpath(filename)), R.style_selected_1)
            locationstr = src + ":" + line

            locationstr += " in "
            locationstr += ansi(self.get_func_name(addr), R.style_selected_1)
            locationstr += "()"

        cond = b["condition"]

        if cond is not None:
            condstr = ansi("{0}".format(cond), R.style_selected_1)
            locationstr += " if {0}".format(condstr)

        addrstr = "0x{0:016x}".format(addr)

        return addrstr, locationstr

    def location_nohighlight(self, b, expr):
        if expr:
            sym, addr = self.location_watch(b)
            line = "{0}".format(sym.line)
            src = "{0}".format(os.path.relpath(sym.symtab.filename))
            locationstr = sym.print_name + " at " + src + ":" + line
        else:
            sym, addr = self.location_break(b)
            line = "{0}".format(sym.line)
            src = "{0}".format(os.path.relpath(sym.symtab.filename))
            locationstr = src + ":" + line
            locationstr += " in " + self.get_func_name(addr) + "()"

        cond = b["condition"]

        if cond is not None:
            locationstr += " if {0}".format(cond)

        addrstr = "0x{0:016x}".format(addr)

        return addrstr, locationstr

    def location_break(self, b):
        loc = b["location"]
        sym = gdb.find_pc_line(gdb.decode_line(loc)[1][0].pc)
        addr = sym.pc

        return sym, addr

    def location_watch(self, b):
        loc = b["expression"]
        sym = gdb.lookup_symbol(loc)[0]
        addr = int(gdb.parse_and_eval(loc).address)

        return sym, addr

    def get_func_name(self, addr):
        block = gdb.current_progspace().block_for_pc(addr)

        if not block.is_static and not block.is_global:
            while block is not None and block.function is None:
                block = block.superblock

        else:
            block = None

        return block.function.print_name if block is not None else "<unknown>"

    def attributes(self):
        return {
            "highlighted": {
                "doc": "Highlight certain elements of each breakpoint.",
                "default": True,
                "type": bool,
            },
        }


class Backtrace(Dashboard.Module):
    def __init__(self):
        self.idx = 0
        self.frame = None
        self.frames = []

    def label(self):
        return "Backtrace"

    def lines(self, term_width, term_height, style_changed):
        self.frame = gdb.selected_frame()
        self.frames = []
        frame = gdb.newest_frame()

        while frame is not None:
            if frame == self.frame:
                self.idx = len(self.frames)

            self.frames.append(frame)
            frame = frame.older()

        out = []

        if len(self.frames) == 0:
            return out

        w = list_len_log10(self.frames)

        for i, f in enumerate(self.frames):
            sym = f.find_sal()
            file = (
                os.path.relpath(sym.symtab.filename)
                if sym and sym.symtab
                else "<unknown_file>"
            )

            if f.function() is None:
                name = "<unknown>"
            else:
                name = f.function().print_name

            if not self.highlighted:
                if i == self.idx:
                    sel = "*"
                else:
                    sel = " "

                s = "{0} [{1:{wid}}]  0x{2:016x} in {3}() at {4}:{5}".format(
                    sel, i, sym.pc, name, file, sym.line, wid=w
                )

            else:
                if i == self.idx:
                    addr_style = R.style_selected_2
                    loc_style = R.style_selected_1
                else:
                    addr_style = R.style_low
                    loc_style = R.style_selected_2

                idxstr = "{0:{width}}".format(i, width=w)

                s = "[{0}]  ".format(ansi(idxstr, loc_style))
                s += ansi("0x{0:016x}".format(sym.pc), addr_style)
                s += " in "
                s += ansi("{0}".format(name), loc_style)
                s += "() at "
                s += ansi("{0}".format(file), loc_style)
                s += ":"
                s += ansi("{0}".format(sym.line), loc_style)

            out.append(s)

        return out

    def attributes(self):
        return {
            "highlighted": {
                "doc": "Highlight certain elements of each stack frame.",
                "default": True,
                "type": bool,
            },
        }
