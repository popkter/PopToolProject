"""Attach only the dependency environment selected by the C++ runtime manager."""
import os
import site
import sys

dependency_directory = os.environ.get("UTERMINAL_PYTHON_SITE_PACKAGES", "")
environment_directory = os.environ.get("VIRTUAL_ENV", "")
if environment_directory and dependency_directory and os.name == "nt":
    from environment_lock import acquire_or_exit
    acquire_or_exit(environment_directory)
if dependency_directory:
    site.addsitedir(dependency_directory)
    dependency_directory = os.path.normcase(os.path.abspath(dependency_directory))
    base_packages = os.path.normcase(os.path.join(sys.base_prefix, "Lib", "site-packages"))
    # The private environment takes precedence over packages bundled in CPython.
    sys.path[:] = [entry for entry in sys.path
                   if os.path.normcase(os.path.abspath(entry)) not in (dependency_directory, base_packages)]
    sys.path.insert(0, dependency_directory)
if environment_directory:
    sys.prefix = environment_directory
    sys.exec_prefix = environment_directory

# Only the affected managed interactive interpreter needs this compatibility
# adapter. Script execution and other Python versions retain their input path.
if (environment_directory and os.name == "nt" and sys.version_info[:2] == (3, 13)
        and getattr(sys.stdin, "isatty", lambda: False)()
        and (sys.flags.interactive or not sys.argv or not sys.argv[0])):
    from repl_unicode import install
    install()
