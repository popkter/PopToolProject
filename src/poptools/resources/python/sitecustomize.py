"""Load PopTools' private venv into the bundled base Python process."""

from __future__ import annotations

import os
import site
import sys

site_packages = os.environ.get("POPTOOLS_PYTHON_SITE_PACKAGES", "")
virtual_environment = os.environ.get("VIRTUAL_ENV", "")

if site_packages:
    site.addsitedir(site_packages)
if virtual_environment:
    sys.prefix = virtual_environment
    sys.exec_prefix = virtual_environment
