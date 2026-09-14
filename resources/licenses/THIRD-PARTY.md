# Third-party components

- Qt 6.10.3: dynamically linked Qt libraries and QML modules. Qt copyright holders; LGPL-3.0 and applicable third-party notices. License copies are included beside this file. Corresponding Qt source: https://download.qt.io/archive/qt/6.10/6.10.3/single/ . Application build scripts use an external Qt SDK; the DLLs are not embedded in the executable and can be replaced with compatible builds.
- libvterm: Copyright (c) 2008 Paul Evans. MIT license in `libvterm-MIT.txt`; vendored source in `native/third_party/libvterm` of this project.
- Material Icons: Google, Apache License 2.0, included in `Material-Icons-Apache-2.0.txt`.
- Microsoft Visual C++ runtime: redistributed application-local DLLs from the installed Visual Studio redistributable directory.

The Python and PowerShell runtimes are optional separately installed plugins. Their upstream licenses remain in their extracted packages.

## Files generated for each installer

`deployed-components.json` records the relative path, size and SHA-256 of every deployed EXE, DLL and font, and maps the top-level Qt DLLs to their SDK module, repository and version. It includes UTerminal's own binaries; it is a deployment inventory, not a list of third-party components alone.

`qt-sbom/` contains the unmodified SPDX JSON documents supplied by the selected Qt SDK for the deployed Qt repositories. These include component copyright information, license expressions and extracted custom license texts. An SDK repository SBOM also describes build tools and components that may not be present in this application; use the deployment inventory to identify the actual shipped files. These documents do not replace the included license texts or an independent release license review.

`UTERMINAL-PATCHES.md` describes the modifications to the vendored libvterm source compiled into UTerminal.
