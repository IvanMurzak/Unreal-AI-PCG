#!/usr/bin/env python3
"""Initialize a new Unreal-MCP extension from this template (cross-platform parity with init.ps1).

Replaces placeholders in file content and in file/folder names, optionally wires a gating engine
plugin into the .uplugin + *.Build.cs, and activates the *.yml-sample workflows.

Placeholders:
  YOUR_EXTENSION_MODULE            the UE plugin + C++ module name (PascalCase, NO hyphens)
  YOUR_EXTENSION_ID                the GetExtensionId() string (e.g. com.company.unreal-ai-feature)
  YOUR_EXTENSION_DISPLAY_NAME      the human-facing name (e.g. "Unreal AI Niagara")
  YOUR_TOOL_ID                     the sample tool id (kebab-case; default "hello-extension")
  YOUR_GITHUB_USERNAME_REPOSITORY  "Owner/Repo"
  YOUR_FEATURE_PLUGIN / YOUR_FEATURE_MODULE   the gating engine plugin/module (optional)

UE module names cannot contain '-'. The repository is conventionally `Unreal-AI-<Feature>`; the UE
plugin/module is the hyphen-free PascalCase form (repo Unreal-AI-Niagara -> module UnrealAINiagara).

Example:
  python commands/init.py --module UnrealAINiagara --id com.company.unreal-ai-niagara \
      --name "Unreal AI Niagara" --repo IvanMurzak/Unreal-AI-Niagara --feature Niagara
"""
import argparse
import os
import re
import sys

IGNORE_DIRS = {".git", "Binaries", "Intermediate", "Saved", "DerivedDataCache",
               "node_modules", ".vs", "commands"}

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def is_ignored(path: str) -> bool:
    rel = os.path.relpath(path, REPO_ROOT).replace("\\", "/")
    parts = rel.split("/")
    return any(p in IGNORE_DIRS for p in parts)


def walk_files():
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if not is_ignored(os.path.join(root, d))]
        for f in files:
            yield os.path.join(root, f)


def walk_all_paths():
    """All files and dirs, deepest first (so children rename before parents)."""
    collected = []
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = [d for d in dirs if not is_ignored(os.path.join(root, d))]
        for name in files + dirs:
            collected.append(os.path.join(root, name))
    collected.sort(key=len, reverse=True)
    return collected


def main() -> int:
    ap = argparse.ArgumentParser(description="Initialize a new Unreal-MCP extension from this template.")
    ap.add_argument("--module", required=True, help="UE plugin + module name (PascalCase, no hyphens)")
    ap.add_argument("--id", required=True, dest="ext_id", help="GetExtensionId() value")
    ap.add_argument("--name", required=True, help="Display name")
    ap.add_argument("--repo", required=True, help="Owner/Repository")
    ap.add_argument("--feature", default="", help="Optional gating engine plugin/module (e.g. Niagara)")
    ap.add_argument("--tool", default="hello-extension", help="Sample tool id (kebab-case)")
    a = ap.parse_args()

    if not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", a.module):
        sys.exit(f"--module '{a.module}' is not a valid UE module name (PascalCase, no hyphens).")
    if not re.match(r"^[a-z0-9]+([._-][a-z0-9]+)*$", a.ext_id):
        sys.exit(f"--id '{a.ext_id}' should be lowercase dotted/kebab.")
    if not re.match(r"^[a-z0-9]+(-[a-z0-9]+)*$", a.tool):
        sys.exit(f"--tool '{a.tool}' must be kebab-case.")
    if not re.match(r"^[^/]+/[^/]+$", a.repo):
        sys.exit(f"--repo '{a.repo}' must be 'Owner/Repository'.")

    replacements = {
        "YOUR_EXTENSION_DISPLAY_NAME": a.name,
        "YOUR_GITHUB_USERNAME_REPOSITORY": a.repo,
        "YOUR_EXTENSION_MODULE": a.module,
        "YOUR_EXTENSION_ID": a.ext_id,
        "YOUR_TOOL_ID": a.tool,
    }
    if a.feature.strip():
        replacements["YOUR_FEATURE_MODULE"] = a.feature
        replacements["YOUR_FEATURE_PLUGIN"] = a.feature
    keys = sorted(replacements, key=len, reverse=True)

    print(f"Initializing extension: module={a.module} id={a.ext_id} name='{a.name}' "
          f"repo={a.repo} tool={a.tool}" + (f" feature={a.feature}" if a.feature.strip() else ""))

    # 1) Replace content.
    for fpath in walk_files():
        try:
            with open(fpath, "r", encoding="utf-8") as fh:
                content = fh.read()
        except (UnicodeDecodeError, PermissionError):
            continue
        new = content
        for k in keys:
            new = new.replace(k, replacements[k])
        if new != content:
            with open(fpath, "w", encoding="utf-8", newline="") as fh:
                fh.write(new)
            print(f"  Updated: {os.path.relpath(fpath, REPO_ROOT)}")

    # 2) Rename files/folders (deepest first).
    for p in walk_all_paths():
        base = os.path.basename(p)
        if "YOUR_EXTENSION_MODULE" in base:
            new_base = base.replace("YOUR_EXTENSION_MODULE", a.module)
            os.rename(p, os.path.join(os.path.dirname(p), new_base))
            print(f"  Renamed: {base} -> {new_base}")

    # 2b) Rename the sample E2E check to match the sample tool id (its filename is the literal
    #     "hello-extension", not a placeholder, so the content pass did not rename it).
    sample_e2e = os.path.join(REPO_ROOT, "Tests", "e2e", "tools", "hello-extension.e2e.ps1")
    if os.path.isfile(sample_e2e) and a.tool != "hello-extension":
        new_e2e = os.path.join(os.path.dirname(sample_e2e), f"{a.tool}.e2e.ps1")
        os.rename(sample_e2e, new_e2e)
        print(f"  Renamed: hello-extension.e2e.ps1 -> {a.tool}.e2e.ps1")

    # 3) Wire the gating engine plugin (optional).
    if a.feature.strip():
        uplugin = next((f for f in walk_files() if f.endswith(".uplugin")), None)
        if uplugin:
            with open(uplugin, "r", encoding="utf-8") as fh:
                u = fh.read()
            core = '    {\n      "Name": "UnrealMCP",\n      "Enabled": true\n    }'
            withf = (core + ',\n    {\n      "Name": "' + a.feature + '",\n      "Enabled": true\n    }')
            if core in u and f'"Name": "{a.feature}"' not in u:
                u = u.replace(core, withf)
                with open(uplugin, "w", encoding="utf-8", newline="") as fh:
                    fh.write(u)
                print(f"  Added '{a.feature}' to .uplugin Plugins array")
        build_cs = next((f for f in walk_files() if f.endswith(".Build.cs")), None)
        if build_cs:
            with open(build_cs, "r", encoding="utf-8") as fh:
                b = fh.read()
            b = b.replace(f'// "{a.feature}",', f'"{a.feature}",')
            b = b.replace(f'// "{a.feature}Editor",', f'"{a.feature}Editor",')
            with open(build_cs, "w", encoding="utf-8", newline="") as fh:
                fh.write(b)
            print(f"  Uncommented feature-module deps in {os.path.basename(build_cs)}")
        # Record the gating engine plugin in extension.json's "enginePlugins" (the catalog hint the
        # install-extension resolver enables in the .uproject alongside this extension).
        ext_json = os.path.join(REPO_ROOT, "extension.json")
        if os.path.isfile(ext_json):
            with open(ext_json, "r", encoding="utf-8") as fh:
                j = fh.read()
            j = re.sub(r'("enginePlugins":\s*)\[\s*\]', r'\1["' + a.feature + '"]', j)
            with open(ext_json, "w", encoding="utf-8", newline="") as fh:
                fh.write(j)
            print(f'  Set extension.json enginePlugins -> ["{a.feature}"]')

    # 4) Activate workflows.
    wf_dir = os.path.join(REPO_ROOT, ".github", "workflows")
    if os.path.isdir(wf_dir):
        for f in os.listdir(wf_dir):
            if f.endswith(".yml-sample"):
                src = os.path.join(wf_dir, f)
                dst = os.path.join(wf_dir, f[:-len("-sample")])
                os.replace(src, dst)
                print(f"  Activated: {f} -> {os.path.basename(dst)}")

    print("Done! See README.md for build + register + release steps.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
