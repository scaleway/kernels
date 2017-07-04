#!/usr/bin/env python

#
# Inside a valid kernel tree, clone Kconfiglib:
# $ git clone git://github.com/ulfalizer/Kconfiglib.git
# If you checked out your kernel from git do:
# $ git am Kconfiglib/makefile.patch
# else if it comes from an archive do
# $ patch -p1 < Kconfiglib/makefile.patch
#
# The following environnement variables must be set beforehand:
#       - AKD_BASE Base kernel config file
#       - AKD_OVERLAY Modules to add to current config
#       - AKD_OUTPUT file to output to
#

import os
import sys

import kconfiglib


def merge_symbol(o_sym, base):
    o_val = o_sym.get_user_value()
    if not o_val:
        return
    sym_name = o_sym.get_name()
    sym_type = o_sym.get_type()
    b_sym = base.get_symbol(o_sym.get_name())
    b_val = b_sym.get_user_value()
    if not b_val:
        b_sym.set_user_value(o_val)
    elif sym_type == kconfiglib.TRISTATE or sym_type == kconfiglib.BOOL:
        new = base.eval('{} || {}'.format(b_val, o_val))
        b_sym.set_user_value(new)
    else:
        b_sym.set_user_value(o_val)
    print('{}: {} -> {}'.format(sym_name, b_val, o_val))


def main(kconfig, base, overlay, output):
    base_conf = kconfiglib.Config(kconfig)
    base_conf.load_config(base)
    overlay_conf = kconfiglib.Config(kconfig)
    overlay_conf.load_config(overlay)
    for o_sym in overlay_conf:
        merge_symbol(o_sym, base_conf)
    base_conf.write_config(output)


if __name__ == '__main__':
    base = os.getenv('AKD_BASE')
    overlay = os.getenv('AKD_OVERLAY')
    output  = os.getenv("AKD_OUTPUT")
    main(sys.argv[1], base, overlay, output)

