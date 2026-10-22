# Embedded Node.js NuGet

This repository builds a family of NuGet packages that bundle prebuilt Node.js executables by RID (win/linux/mac x64/arm64) so consumers such as `JavaScriptEngineSwitcher.Node` can run without a machine-wide Node.js installation.

This is the `main-v26` branch, which ships **Node.js 26** as the `Envisia.EmbeddedNodeJs26*` packages. The `main` branch ships Node.js 24 as the `Envisia.EmbeddedNodeJs*` packages.

## Project layout
- `src/NodeJs.Embedded`: Helper API (`NodeRuntimeLocator`) and documentation package (no binaries).
- `src/NodeJs.Embedded.Native.<rid>`: Runtime-only packages for each RID (win-x64, win-arm64, linux-x64, linux-arm64, osx-x64, osx-arm64).
- `scripts/download-node.sh`: Utility that downloads platform archives from `nodejs.org`, extracts the `node` executable, and populates each `Native.<rid>/runtimes/<rid>/native/`.
- `.github/workflows/publish.yml`: GitHub Actions workflow that fetches Node binaries, packs all packages, and can publish the NuGet packages.

## Local workflow
```bash
# Fetch Node distributions (customize NODE_VERSION as needed)
./scripts/download-node.sh 26.12.1

# Pack all packages
dotnet pack src/NodeJs.Embedded/NodeJs.Embedded.csproj -c Release
for proj in src/NodeJs.Embedded.Native.*/NodeJs.Embedded.Native.*.csproj; do
  dotnet pack "$proj" -c Release
done
```
To align local packs with a tag version, pass `/p:Version=<tag>` and `/p:EmbeddedNodeJsNativeVersion=<tag>` to the helper pack and `/p:Version=<tag>` to the native packs.

## Using with JavaScriptEngineSwitcher.Node
1. Add package references. If your project sets a single `RuntimeIdentifier`, the helper package will pull in the matching native package automatically via `buildTransitive/Envisia.EmbeddedNodeJs26.props`. For multi-RID builds, add conditional references explicitly.
   ```xml
   <PackageReference Include="JavaScriptEngineSwitcher.Node" Version="*-use-your-version*" />
   <PackageReference Include="Envisia.EmbeddedNodeJs26" Version="0.2.0" />
   ```
   For multi-RID builds, conditionally reference the native packages (the helper cannot infer multiple RIDs):
   ```xml
   <ItemGroup Condition="'$(RuntimeIdentifier)'=='win-x64'">
      <PackageReference Include="Envisia.EmbeddedNodeJs26.Native.win-x64" Version="0.2.0" />
   </ItemGroup>
   <ItemGroup Condition="'$(RuntimeIdentifier)'=='linux-x64'">
     <PackageReference Include="Envisia.EmbeddedNodeJs26.Native.linux-x64" Version="0.2.0" />
   </ItemGroup>
   <!-- add other RIDs as needed -->
   ```
2. Resolve the embedded Node path and pass it to your Node engine settings (examples for .NET DI):
   ```csharp
   services
       .AddJsEngineSwitcher(options => options.DefaultEngineName = NodeJsEngine.EngineName)
       .AddNode();

   services
       .AddNodeJS()
       .Configure<NodeJSProcessOptions>(nodeProcessOptions =>
       {
           nodeProcessOptions.ExecutablePath = NodeRuntimeLocator.GetNodeExecutablePath();
       });
   ```
3. The runtime-specific `node`/`node.exe` is copied automatically from `runtimes/<rid>/native/` into your build output when the correct native package is referenced (automatically when a single RID is set, or explicitly for multi-RID projects).

## GitHub Actions
- Workflow builds on `ubuntu-latest` with .NET 9 for pushes to `main-v26`, `node26-v*` tags, and pull requests.
- Downloads Node archives for `win-x64`, `win-arm64`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64` (default `NODE_VERSION=26.12.1`).
- Packs all helper + native packages and uploads them as artifacts.
- On a release tag, a separate `publish` job pushes the packages to nuget.org with [trusted publishing](https://learn.microsoft.com/nuget/nuget-org/trusted-publishing), so no API key is stored in the repository. It needs:
  - a trusted publishing policy on nuget.org (owned by the account that owns the packages) with Repository Owner `schmitch`, Repository `embedded-node-js`, Workflow File `publish.yml` and Environment `nuget`;
  - a GitHub Actions secret `NUGET_USER` with that account's nuget.org profile name (not the email address);
  - optionally, protection rules on the `nuget` GitHub environment (for example, only the release tags may deploy, or a required reviewer).
- If the workflow runs on a tag `node26-vX.Y.Z`, `X.Y.Z` is used as the package version; otherwise it defaults to 0.2.0. Plain `vX.Y.Z` tags are the Node 24 releases from `main` and are ignored by this branch's workflow.

## Keeping Node.js up to date
`.claude/settings.json` registers a Claude Code `SessionStart` hook (`.claude/hooks/check-node-update.sh`). When a new session starts, at most once a month (counted from the last check in this checkout or the last commit that changed `NODE_VERSION`), it looks up the newest Node.js release on `nodejs.org` that ships all six archives. If that release is newer than `NODE_VERSION`, Claude offers to bump it and verify the downloads. Set `NODE_UPDATE_CHECK_FORCE=1` to skip the monthly throttle.
