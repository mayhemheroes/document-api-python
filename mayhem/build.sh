#!/usr/bin/env bash
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer -g}"
: "${CC:=clang}" ; : "${CXX:=clang++}"
: "${MAYHEM_JOBS:=$(nproc)}"
export CC CXX MAYHEM_JOBS

cd "$SRC"

# tableaudocumentapi imports `from distutils.version import LooseVersion`, but the
# base image runs Python 3.13 where distutils was removed. setuptools<81 still
# vendors a `distutils` shim and registers it as a top-level import, so pinning
# setuptools below 81 restores `import distutils` without touching upstream code.
SETUPTOOLS_PIN="setuptools<81"

# Test oracle: clean venv (no sanitizers).
python3 -m venv /mayhem/test-venv
/mayhem/test-venv/bin/pip install --upgrade pip wheel
/mayhem/test-venv/bin/pip install "$SETUPTOOLS_PIN"
(
  export CC=clang CXX=clang++
  unset CFLAGS CXXFLAGS LDFLAGS
  /mayhem/test-venv/bin/pip install -e .
)

# Fuzz build: separate venv with atheris + PyInstaller ELF.
python3 -m venv /mayhem/fuzz-venv
/mayhem/fuzz-venv/bin/pip install --upgrade pip wheel
/mayhem/fuzz-venv/bin/pip install "$SETUPTOOLS_PIN"
export CFLAGS="$SANITIZER_FLAGS" CXXFLAGS="$SANITIZER_FLAGS" LDFLAGS="$SANITIZER_FLAGS"
/mayhem/fuzz-venv/bin/pip install atheris pyinstaller
/mayhem/fuzz-venv/bin/pip install -e .

$CC -shared -fPIC -o /mayhem/asan_defaults.so "$SRC/mayhem/asan_defaults.c"

/mayhem/fuzz-venv/bin/pyinstaller \
  --distpath /tmp/pyinst-out \
  --workpath /tmp/pyinst-work \
  --specpath /tmp/pyinst-spec \
  --onefile \
  --name fuzz-twb \
  --paths "$SRC/mayhem" \
  --collect-all tableaudocumentapi \
  --collect-all lxml \
  --collect-submodules distutils \
  --hidden-import fuzz_helpers \
  --hidden-import distutils \
  --hidden-import distutils.version \
  --hidden-import lxml.etree \
  --hidden-import lxml._elementpath \
  --hidden-import tempfile \
  --hidden-import contextlib \
  --hidden-import io \
  --hidden-import zipfile \
  --hidden-import shutil \
  --hidden-import weakref \
  --hidden-import functools \
  --hidden-import itertools \
  --hidden-import collections \
  --hidden-import uuid \
  --hidden-import xml.etree.ElementTree \
  --hidden-import xml.dom \
  --hidden-import xml.dom.minidom \
  --hidden-import xml.sax \
  --hidden-import xml.sax.saxutils \
  --collect-submodules xml \
  --hidden-import packaging \
  --hidden-import packaging.version \
  --add-binary /mayhem/asan_defaults.so:. \
  "$SRC/mayhem/fuzz_twb.py"

install -m 0755 /tmp/pyinst-out/fuzz-twb /mayhem/fuzz-twb
