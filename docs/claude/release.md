# Release

## Version single source

The `.uplugin` `VersionName` is the **single source of truth**. `commands/bump-version.ps1` updates
it together with `GetExtensionVersion()` in the module and `version` in `extension.json`, so they can
never drift. Never hand-edit one location alone.

```powershell
./commands/bump-version.ps1 -NewVersion "0.2.0"          # apply
./commands/bump-version.ps1 -NewVersion "0.2.0" -WhatIf  # preview
./commands/get-version.ps1                                # read current
```

## The version gate

`release.yml` runs on every push to `main` but **publishes nothing unless the version changed**:

1. `check-version-tag` reads `VersionName` from the `.uplugin`, finds the previous tag, and checks
   whether the tag `v<version>` already exists. The release **tag is `v<version>`** (with the
   leading `v`) — the form `unreal-mcp-cli install-extension` downloads from
   (`releases/download/v<version>/...`); the `name` is the bare semver.
2. Every downstream job is `if: needs.check-version-tag.outputs.tag_exists == 'false'`.

So a normal merge that does not bump the version is a no-op for releases. This is the Unreal analog
of Unity's `package.json` + tag gate.

## Atomic, all-gated publish

The `release` job `needs` **every** test job (per UE version) **and** the `package` job **and** the
release-notes job. It downloads the source zip and creates the GitHub Release **+ tag** in a single
`softprops/action-gh-release@v2` call (`fail_on_unmatched_files: true`). A failed test → **no
release**; a stranded asset can't produce a partial release. This mirrors Unity's atomic
`release-unity-plugin`.

## What the release carries

A **single source zip `<Module>-<version>.zip`** (the plugin source folder, `<Module>/<Module>.uplugin`
at the archive root), built with `git archive` so only tracked files ship (no `Binaries/`/`Intermediate/`).
This is exactly what `unreal-mcp-cli install-extension` downloads and unpacks into a consumer project's
`Plugins/<Module>/`; **UE then compiles the extension on the next editor open** (the source-ship model,
design note §5).

> **Why source, not `BuildPlugin` binaries?** An extension depends on the `UnrealMCP` plugin, and a
> standalone `BuildPlugin -Rocket` builds in an isolated HostProject that **cannot resolve `UnrealMCP`**
> unless it is installed into `UE_ROOT\Engine\Plugins\Marketplace`. Shipping source sidesteps that and
> needs no UE / no self-hosted runner to package. If you want precompiled per-UE binaries instead, add a
> `BuildPlugin` job that first engine-installs `UnrealMCP`, and append its zip(s) to the release.

## Tracking the core version

`commands/update-core.ps1` queries the latest `IvanMurzak/Unreal-MCP` release and records it as
`minCoreVersion` in `extension.json` — the compatibility floor the install resolver reads. It does
**not** pin a version inside the `.uplugin` (a UE plugin dependency carries no version); the floor is
advisory install-catalog metadata.

## Typical release flow

1. `./commands/bump-version.ps1 -NewVersion "x.y.z"` (or run the `bump_version` workflow → merge its PR).
2. Push/merge to `main`.
3. `release.yml` sees a fresh version, runs the full suite, packages the source zip, and publishes the
   atomic Release + tag `vx.y.z`.
