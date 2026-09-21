import os

from PySide6.QtWebEngineQuick import QtWebEngineQuick

# Keep QML tests aligned with the application startup configuration.  GitHub
# Actions installs a standalone Qt SDK for the native build, and that SDK can
# otherwise make QtQuick.Controls auto-select its Windows style instead of the
# Basic style shipped with the PySide runtime used by the tests.
os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Basic")

# Match main(): shared graphics contexts must be set up before qapp is created.
QtWebEngineQuick.initialize()
