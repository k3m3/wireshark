#
# -*- coding: utf-8 -*-
# Wireshark tests
# By Gerald Combs <gerald@wireshark.org>
#
# Ported from a set of Bash scripts which were copyright 2005 Ulf Lamping
#
# SPDX-License-Identifier: GPL-2.0-or-later
#
'''Configuration'''

import os
import os.path
import re
import subprocess
import sys
import tempfile

commands = (
    'capinfos',
    'dumpcap',
    'mergecap',
    'rawshark',
    'tshark',
    'wireshark',
)

can_capture = False
capture_interface = None

# Our executables
# Strings
cmd_capinfos = None
cmd_dumpcap = None
cmd_mergecap = None
cmd_rawshark = None
cmd_tshark = None
cmd_wireshark = None
# Arrays
args_ping = None

have_lua = False
have_nghttp2 = False
have_kerberos = False
have_libgcrypt17 = False

test_env = None
home_path = None
conf_path = None
this_dir = os.path.dirname(__file__)
baseline_dir = os.path.join(this_dir, 'baseline')
capture_dir = os.path.join(this_dir, 'captures')
config_dir = os.path.join(this_dir, 'config')
key_dir = os.path.join(this_dir, 'keys')
lua_dir = os.path.join(this_dir, 'lua')

def canCapture():
    # XXX This appears to be evaluated at the wrong time when called
    # from a unittest.skipXXX decorator.
    return can_capture and capture_interface is not None

def setCanCapture(new_cc):
    can_capture = new_cc

def setCaptureInterface(iface):
    global capture_interface
    setCanCapture(True)
    capture_interface = iface

def canMkfifo():
    return not sys.platform.startswith('win32')

def canDisplay():
    if sys.platform.startswith('win32') or sys.platform.startswith('darwin'):
        return True
    # Qt requires XKEYBOARD and Xrender, which Xvnc doesn't provide.
    return False

def getTsharkInfo():
    global have_lua
    global have_nghttp2
    global have_kerberos
    global have_libgcrypt17
    have_lua = False
    have_nghttp2 = False
    have_kerberos = False
    have_libgcrypt17 = False
    try:
        tshark_v_blob = str(subprocess.check_output((cmd_tshark, '--version'), stderr=subprocess.PIPE))
        tshark_v = ' '.join(tshark_v_blob.splitlines())
        if re.search('with +Lua', tshark_v):
            have_lua = True
        if re.search('with +nghttp2', tshark_v):
            have_nghttp2 = True
        if re.search('(with +MIT +Kerberos|with +Heimdal +Kerberos)', tshark_v):
            have_kerberos = True
        gcry_m = re.search('with +Gcrypt +([0-9]+\.[0-9]+)', tshark_v)
        have_libgcrypt17 = gcry_m and float(gcry_m.group(1)) >= 1.7
    except:
        pass

def getDefaultCaptureInterface():
    '''Choose a default capture interface for our platform. Currently Windows only.'''
    global capture_interface
    if capture_interface:
        return
    if cmd_dumpcap is None:
        return
    if not sys.platform.startswith('win32'):
        return
    try:
        dumpcap_d_blob = str(subprocess.check_output((cmd_dumpcap, '-D'), stderr=subprocess.PIPE))
        for d_line in dumpcap_d_blob.splitlines():
            iface_m = re.search('(\d+)\..*(Ethernet|Network Connection|VMware|Intel)', d_line)
            if iface_m:
                capture_interface = iface_m.group(1)
                break
    except:
        pass

def getPingCommand():
    '''Return an argument list required to ping www.wireshark.org for 60 seconds.'''
    global args_ping
    # XXX The shell script tests swept over packet sizes from 1 to 240 every 0.25 seconds.
    if sys.platform.startswith('win32'):
        # XXX Check for psping? https://docs.microsoft.com/en-us/sysinternals/downloads/psping
        args_ping = ('ping', '-n', '60', '-l', '100', 'www.wireshark.org')
    elif sys.platform.startswith('linux') or sys.platform.startswith('freebsd'):
        args_ping = ('ping', '-c', '240', '-s', '100', '-i', '0.25', 'www.wireshark.org')
    elif sys.platform.startswith('darwin'):
        args_ping = ('ping', '-c', '1', '-g', '1', '-G', '240', '-i', '0.25', 'www.wireshark.org')
    # XXX Other BSDs, Solaris, etc

def setProgramPath(path):
    global program_path
    program_path = path
    retval = True
    dotexe = ''
    if sys.platform.startswith('win32'):
        dotexe = '.exe'
    for cmd in commands:
        cmd_var = 'cmd_' + cmd
        cmd_path = os.path.join(path, cmd + dotexe)
        if not os.path.exists(cmd_path) or not os.access(cmd_path, os.X_OK):
            cmd_path = None
            retval = False
        globals()[cmd_var] = cmd_path
    getTsharkInfo()
    getDefaultCaptureInterface()
    return retval

def testEnvironment():
    return test_env

def setUpTestEnvironment():
    global home_path
    global conf_path
    global test_env
    test_confdir = tempfile.mkdtemp(prefix='wireshark-tests.')
    home_path = os.path.join(test_confdir, 'home')
    if sys.platform.startswith('win32'):
        home_env = 'APPDATA'
        conf_path = os.path.join(home_path, 'Wireshark')
    else:
        home_env = 'HOME'
        conf_path = os.path.join(home_path, '.config', 'wireshark')
    os.makedirs(conf_path)
    test_env = os.environ.copy()
    test_env[home_env] = home_path

def setUpConfigFile(conf_file):
    global home_path
    global conf_path
    if home_path is None or conf_path is None:
        setUpTestEnvironment()
    template = os.path.join(os.path.dirname(__file__), 'config', conf_file) + '.tmpl'
    with open(template, 'r') as tplt_fd:
        tplt_contents = tplt_fd.read()
        tplt_fd.close()
        key_dir_path = os.path.join(key_dir, '')
        # uat.c replaces backslashes...
        key_dir_path = key_dir_path.replace('\\', '\\x5c')
        cf_contents = tplt_contents.replace('TEST_KEYS_DIR', key_dir_path)
    out_file = os.path.join(conf_path, conf_file)
    with open(out_file, 'w') as cf_fd:
        cf_fd.write(cf_contents)
        cf_fd.close()

if sys.platform.startswith('win32') or sys.platform.startswith('darwin'):
    can_capture = True

# Initialize ourself.
getPingCommand()
setProgramPath(os.path.curdir)
