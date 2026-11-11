"""Print the zones of the most fragmented location vector of the zone graph of a posbadall product (see zone_probe.py).
Usage (WSL): python3 zone_dump.py ID ARM [K]   ARM in ours|casaal_exp; prints K zones (default 8)."""
import os, re, sys, subprocess, tempfile, shutil, collections
HERE = os.path.dirname(os.path.abspath(__file__))
sys.argv = [sys.argv[0], '/dev/null', '200'] + [] if False else sys.argv
