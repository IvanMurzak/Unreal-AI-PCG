<h1 align="center">Unreal AI Template</h1>

<p align="center">
  Template for authoring <b>MCP tool extensions</b> for
  <a href="https://github.com/IvanMurzak/Unreal-MCP">AI Game Developer (Unreal-MCP)</a>.
  Use it to scaffold a new Unreal-MCP extension — a C++ editor plugin that contributes AI tools an
  agent can call against the Unreal Editor — in minutes.
</p>

---

An **extension** is a normal Unreal Engine **`Type=Editor` plugin** that implements the Unreal-MCP
contract `IUnrealMcpToolProvider` and registers its tools through a fluent builder. Unreal-MCP
discovers it at boot (and live, when it loads later) and merges its tools into the advertised tool
set. Enabling/disabling an extension live-updates what the AI sees — so you ship only the tools a
task needs.

> Authoring is **C++** (unlike Unity's C# `[McpPluginTool]`). This template gives you a buildable
> skeleton, a sample tool, setup scripts, and CI so you can focus on your tools.

## What you get

```
YOUR_EXTENSION_MODULE/                                   the UE plugin (renamed by init)
├── YOUR_EXTENSION_MODULE.uplugin                         descriptor; Plugins: [ UnrealMCP, <feature> ]
└── Source/YOUR_EXTENSION_MODULE/
    ├── YOUR_EXTENSION_MODULE.Build.cs                    deps: UnrealMcpRuntime + UnrealMcpEditor (+ your feature)
    └── Private/
        ├── YOUR_EXTENSION_MODULEModule.cpp               provider + module (1 sample tool)
        └── Tests/YOUR_EXTENSION_MODULESpec.cpp           sample UE Automation spec (1 per tool)
commands/                                                 init / bump-version / get-version / update-core
Tests/e2e/                                                E2E unreal-mcp-cli tool checks (1 per tool)
extension.json                                            install-catalog / compat manifest
.github/workflows/                                        CI (test_pull_request + release ship as *.yml-sample)
```

# Steps to make your extension

### 1. Create your repository from this template

Click **“Use this template” → “Create a new repository”** on GitHub (this repo has the *Template*
flag enabled), name it `Unreal-AI-<Feature>` (e.g. `Unreal-AI-Niagara`), then clone it.

### 2. Initialize (rename + replace placeholders + activate CI)

UE module names **cannot contain `-`**. The *repository* is `Unreal-AI-<Feature>`; the *plugin/module*
is the hyphen-free PascalCase form (e.g. `UnrealAINiagara`).

```powershell
# Windows / PowerShell
./commands/init.ps1 `
  -ExtensionModule  "UnrealAINiagara" `
  -ExtensionId      "com.company.unreal-ai-niagara" `
  -DisplayName      "Unreal AI Niagara" `
  -GitHubRepository "YourName/Unreal-AI-Niagara" `
  -FeaturePlugin    "Niagara"          # optional — the engine plugin your tools wrap
```

```bash
# macOS / Linux (or anywhere with Python 3)
python commands/init.py \
  --module UnrealAINiagara \
  --id com.company.unreal-ai-niagara \
  --name "Unreal AI Niagara" \
  --repo YourName/Unreal-AI-Niagara \
  --feature Niagara
```

`init` will:
- replace `YOUR_EXTENSION_MODULE`, `YOUR_EXTENSION_ID`, `YOUR_EXTENSION_DISPLAY_NAME`,
  `YOUR_TOOL_ID`, `YOUR_GITHUB_USERNAME_REPOSITORY` in file **content and names**;
- when `-FeaturePlugin` is given, add it to the `.uplugin` `Plugins` array and uncomment the
  feature-module dependencies in `*.Build.cs`;
- activate the CI workflows (`*.yml-sample` → `*.yml`).

### 3. Set the gating engine plugin (if you skipped `-FeaturePlugin`)

Your extension typically wraps one engine plugin (Niagara, Chaos, …). That dependency **is the
gating**: the extension won't compile or load without it.

1. In `<Module>.uplugin`, add the plugin to `Plugins`:
   ```json
   "Plugins": [
     { "Name": "UnrealMCP", "Enabled": true },
     { "Name": "Niagara",   "Enabled": true }
   ]
   ```
2. In `Source/<Module>/<Module>.Build.cs`, uncomment + rename the feature-module deps
   (e.g. `"Niagara"`, `"NiagaraEditor"`).

> Default policy is **opt-in / off**: an extension is a real dependency with build + context cost, so
> users enable only what they need.

### 4. Build against a UE project (UBT)

An extension is compiled by Unreal Build Tool inside a host project that also has the **UnrealMCP
core plugin** available. The fastest local loop is a directory junction:

```powershell
# From a UE C++ project that has Plugins/UnrealMCP available:
cmd /c mklink /J "<UEProject>\Plugins\UnrealAINiagara" "<thisRepo>\UnrealAINiagara"

& "C:\Program Files\Epic Games\UE_5.7\Engine\Build\BatchFiles\Build.bat" `
  <UEProject>Editor Win64 Development -project="<UEProject>\<UEProject>.uproject" -WaitMutex
```

A clean build compiles your module and its sample tool + Automation spec. Run the specs with:

```powershell
& "C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" `
  "<UEProject>\<UEProject>.uproject" -nullrhi -nosplash -unattended `
  -ExecCmds="Automation RunTests UnrealAINiagara; Quit" -ReportExportPath="<dir>" -log
```

### 5. Register & see your tools in AI Game Developer

Enable both plugins in the project, open the editor, and connect AI Game Developer (the
Unreal-MCP UI / sidecar). Your `StartupModule` registers the provider as a modular feature, so
your tools appear in the tool list immediately. Toggling the extension live-updates the advertised
tools.

### 6. Add your tools

Edit `Source/<Module>/Private/<Module>Module.cpp` → `RegisterTools()`. Tool ids are **kebab-case**.
The handler runs on the **game thread**, so you may call editor/engine APIs directly:

```cpp
Registry.Tool(TEXT("niagara-system-create"))
    .Title(TEXT("Create Niagara System"))
    .Description(TEXT("Creates a new Niagara system asset at the given path."))
    .ParamString(TEXT("path"), TEXT("Content path, e.g. /Game/VFX/MySystem"))
    .Handle([](const FUnrealMcpToolCall& Call) -> FUnrealMcpToolResult
    {
        const FString Path = Call.GetString(TEXT("path"));
        // ... use NiagaraEditor APIs here ...
        return FUnrealMcpToolResult::Success(FString::Printf(TEXT("Created %s"), *Path));
    });
```

For each new tool, add **(1)** a focused UE Automation spec (copy the `It(...)` block in
`Tests/<Module>Spec.cpp`) and **(2)** an E2E check (`Tests/e2e/tools/<tool>.e2e.ps1`).
See the [Unreal-MCP extension author guide](https://github.com/IvanMurzak/Unreal-MCP/blob/main/docs/EXTENSIONS.md).

### 7. Release

Versioning is single-sourced from the `.uplugin` `VersionName`. Bump it in lock-step:

```powershell
./commands/bump-version.ps1 -NewVersion "0.2.0"   # updates .uplugin + GetExtensionVersion() + extension.json
```

Push to `main`. **`release.yml` is version-gated**: when the `VersionName` is a new value with no
existing tag, it runs the full test suite, packages the plugin **source** into a single
`<Module>-<version>.zip`, and creates an **atomic GitHub Release** (tag `v<version>`) carrying that
zip — the exact asset the installer downloads. The extension ships as source and UE compiles it on
the consumer's next editor open. (Track the core version floor with `./commands/update-core.ps1`.)

### 8. Install via the CLI

Once released, anyone installs your extension into a UE project with (the project path is a
**positional** argument):

```bash
unreal-mcp-cli install-extension <extensionId> <UEProject>
# offline / from a local checkout (no published release needed):
unreal-mcp-cli install-extension <extensionId> <UEProject> --source <path-to-plugin-dir>
```

The CLI resolves the release zip (`releases/download/v<version>/<Module>-<version>.zip`), places the
plugin in `Plugins/<Module>/`, enables it (and its gating engine plugin) in the `.uproject`, and the
editor recompiles it on next open (or pass `--build` to compile now via UBT). The same capability
backs the AI-Game-Dev desktop app button and the in-editor Extensions panel.

---

## CI & secrets

CI ships as `*.yml-sample` and is activated by `init`:

| Workflow | When | What |
| --- | --- | --- |
| `test_unreal_plugin.yml` | reusable | UBT build + UE Automation specs for one UE version |
| `test_pull_request.yml` | PR | the reusable test per UE version (5.6/5.7) + E2E `unreal-mcp-cli` tool checks |
| `release.yml` | push to `main` | version-gated → full tests → package source zip `<Module>-<version>.zip` → atomic GitHub Release (tag `v<version>`) |
| `bump_version.yml` | manual | runs `bump-version.ps1`, opens a release PR |

The plugin/E2E jobs run on a **self-hosted Windows UE runner** and are **never red-by-absence** —
they stay *skipped* until you register a runner and set the repo variables:

- `UNREAL_RUNNER_READY = true` — enables the UBT build + Automation legs.
- `UNREAL_E2E_READY = true` — enables the E2E `install-extension` + tool-invocation leg.
- `UNREAL_HOST_PROJECT` — absolute path on the runner to a host `.uproject` with UnrealMCP available.

See [`docs/claude/ci.md`](docs/claude/ci.md) and [`docs/claude/release.md`](docs/claude/release.md).

## License

[Apache-2.0](LICENSE).
