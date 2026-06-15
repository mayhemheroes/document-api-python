#!/usr/bin/env python3
"""Atheris harness for tableau document-api-python.

Honest successor of the original mayhemheroes `fuzz-twb` target: it drives the
public `Workbook(filename)` entry point, which opens and parses a Tableau
workbook (`.twb`) XML file via lxml. Fuzz bytes are written to a temporary
`.twb` file and handed to `Workbook`.
"""
import sys

import atheris

import fuzz_helpers

with atheris.instrument_imports(include=['tableaudocumentapi']):
    from tableaudocumentapi import Workbook

from lxml.etree import XMLSyntaxError, LxmlError
from tableaudocumentapi.xfile import (
    TableauVersionNotSupportedException,
    TableauInvalidFileException,
)

# Exceptions the library legitimately raises (or lets propagate) for malformed
# or unexpected input. Anything else is a genuine, unexpected crash.
EXPECTED = (
    XMLSyntaxError,
    LxmlError,
    TableauVersionNotSupportedException,
    TableauInvalidFileException,
    ValueError,
    AttributeError,
    KeyError,
    TypeError,
    # lxml reports malformed file encoding / unreadable input from ET.parse as a
    # plain OSError (not XMLSyntaxError); that is an expected rejection of bad
    # input, not a library defect.
    OSError,
)


def TestOneInput(data):
    fdp = fuzz_helpers.EnhancedFuzzedDataProvider(data)
    try:
        with fdp.ConsumeTemporaryFile('.twb', all_data=True, as_bytes=True) as filename:
            Workbook(filename)
    except EXPECTED:
        return -1


def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
