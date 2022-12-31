#!/usr/bin/env python3
import random

import atheris
import sys


import fuzz_helpers
import random

with atheris.instrument_imports(include=['tableaudocumentapi']):
    from tableaudocumentapi import Workbook

from lxml.etree import XMLSyntaxError
from tableaudocumentapi.xfile import TableauVersionNotSupportedException

def TestOneInput(data):
    fdp = fuzz_helpers.EnhancedFuzzedDataProvider(data)
    try:
        with fdp.ConsumeTemporaryFile('.twb', all_data=True, as_bytes=True) as filename:
            Workbook(filename)
    except (XMLSyntaxError, TableauVersionNotSupportedException, ValueError, AttributeError):
        return -1
    except TypeError:
        if random.random() > .99:
            raise
        return -1
def main():
    atheris.Setup(sys.argv, TestOneInput)
    atheris.Fuzz()


if __name__ == "__main__":
    main()
