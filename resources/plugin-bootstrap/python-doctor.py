"""Structured diagnostics executed only by the explicitly selected plugin Python."""
import ast
import contextlib
import importlib
import importlib.metadata
import io
import json
import os
from pathlib import Path
import sys

PACKAGE_NAMES = {
    "bs4": "beautifulsoup4", "Crypto": "pycryptodome", "cv2": "opencv-python",
    "dateutil": "python-dateutil", "dotenv": "python-dotenv", "fitz": "PyMuPDF",
    "jwt": "PyJWT", "PIL": "Pillow", "serial": "pyserial", "sklearn": "scikit-learn",
    "yaml": "PyYAML", "pkg_resources": "setuptools<82", "lunar_python": "lunar-python",
}


def inspect_source(source, directory):
    result = {"checked": [], "missing": [], "suggestions": [], "errors": [], "syntaxError": ""}
    try:
        tree = ast.parse(source)
    except SyntaxError as error:
        result["syntaxError"] = f"第 {error.lineno} 行：{error.msg}"
        return result
    modules = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules.update(alias.name.split(".")[0] for alias in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            modules.add(node.module.split(".")[0])
    for name in sorted(modules):
        result["checked"].append(name)
        if name in sys.stdlib_module_names or name in sys.builtin_module_names:
            continue
        if directory and ((Path(directory) / f"{name}.py").is_file() or (Path(directory) / name).is_dir()):
            continue
        try:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                importlib.import_module(name)
        except ModuleNotFoundError as error:
            missing = (error.name or name).split(".")[0]
            if missing not in result["missing"]:
                result["missing"].append(missing)
        except Exception as error:
            result["errors"].append({"module": name, "message": str(error)})
    result["suggestions"] = list(dict.fromkeys(PACKAGE_NAMES.get(name, name) for name in result["missing"]))
    return result


def environment_info():
    # Keep the first distribution on sys.path, matching actual import precedence.
    packages = {}
    for distribution in importlib.metadata.distributions():
        name = distribution.metadata.get("Name", "")
        key = name.lower().replace("_", "-").replace(".", "-")
        packages.setdefault(key, {"name": name, "version": distribution.version})
    return {
        "executable": sys.executable, "prefix": sys.prefix, "basePrefix": sys.base_prefix,
        "version": sys.version.split()[0], "sitePackages": os.environ.get("UTERMINAL_PYTHON_SITE_PACKAGES", ""),
        "searchPath": sys.path,
        "packages": sorted(packages.values(), key=lambda package: package["name"].lower()),
    }


def main():
    request_path, result_path = sys.argv[1:3]
    request = json.loads(Path(request_path).read_text(encoding="utf-8"))
    result = environment_info()
    if request.get("action") == "probe":
        result["diagnostics"] = inspect_source(request.get("source", ""), request.get("directory", ""))
    Path(result_path).write_text(json.dumps(result, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    main()
