import os


class FileExists(gdb.Function):
    """Returns true if a file exists, false otherwise."""

    def __init__(self):
        super(FileExists, self).__init__("file_exists")

    def invoke(self, name):
        try:
            namestr = name.string()
            ret = os.path.isfile(os.path.abspath(namestr))
        except:
            ret = False
        return ret


FileExists()
