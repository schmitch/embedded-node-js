# Embedded Node.js NuGet

This repository builds a family of NuGet packages that bundle prebuilt Node.js executables by RID (win/linux/mac x64/arm64) so consumers such as `JavaScriptEngineSwitcher.Node` can run without a machine-wide Node.js installation.

## Project layout
- `src/NodeJs.Embedded`: Helper API (`NodeRuntimeLocator`) and documentation package (no binaries).
- `src/NodeJs.Embedded.Native.<rid>`: Runtime-only packages for each RID (win-x64, win-arm64, linux-x64, linux-arm64, osx-x64, osx-arm64).
- `scripts/download-node.sh`: Utility that downloads platform archives from `nodejs.org`, extracts the `node` executable, and populates each `Native.<rid>/runtimes/<rid>/native/`.
- `.github/workflows/publish.yml`: GitHub Actions workflow that fetches Node binaries, packs all packages, and can publish the NuGet packages.

## Local workflow
```bash
# Fetch Node distributions (customize NODE_VERSION as needed)
./scripts/download-node.sh 22.21.1

# Pack all packages
dotnet pack src/NodeJs.Embedded/NodeJs.Embedded.csproj -c Release
for proj in src/NodeJs.Embedded.Native.*/NodeJs.Embedded.Native.*.csproj; do
  dotnet pack "$proj" -c Release
done
```
To align local packs with a tag version, pass `/p:Version=<tag>` and `/p:EmbeddedNodeJsNativeVersion=<tag>` to the helper pack and `/p:Version=<tag>` to the native packs.

## Using with JavaScriptEngineSwitcher.Node
1. Add package references. If your project sets a single `RuntimeIdentifier`, the helper package will pull in the matching native package automatically via `buildTransitive/EmbeddedNodeJs.props`. For multi-RID builds, add conditional references explicitly.
   ```xml
   <PackageReference Include="JavaScriptEngineSwitcher.Node" Version="*-use-your-version*" />
   <PackageReference Include="EmbeddedNodeJs" Version="0.2.0" />
   ```
   For multi-RID builds, conditionally reference the native packages (the helper cannot infer multiple RIDs):
   ```xml
   <ItemGroup Condition="'$(RuntimeIdentifier)'=='win-x64'">
      <PackageReference Include="EmbeddedNodeJs.Native.win-x64" Version="0.2.0" />
   </ItemGroup>
   <ItemGroup Condition="'$(RuntimeIdentifier)'=='linux-x64'">
     <PackageReference Include="EmbeddedNodeJs.Native.linux-x64" Version="0.2.0" />
   </ItemGroup>
   <!-- add other RIDs as needed -->
   ```
2. Resolve the embedded Node path and pass it to the Node engine settings (example for .NET DI):
   ```csharp
   using JavaScriptEngineSwitcher.Extensions.MsDependencyInjection;
   using JavaScriptEngineSwitcher.Node;
   using NodeJs.Embedded;

   services.AddSingleton<IJsEngineSwitcher, JsEngineSwitcher>(provider =>
   {
       var switcher = new JsEngineSwitcher(provider);
       var nodeSettings = new NodeSettings
       {
           EngineExecutablePath = NodeRuntimeLocator.GetNodeExecutablePath()
       };
       switcher.EngineFactories.Add(new NodeJsEngineFactory(nodeSettings));
       return switcher;
   });
   ```
3. The runtime-specific `node`/`node.exe` is copied automatically from `runtimes/<rid>/native/` into your build output when the correct native package is referenced (automatically when a single RID is set, or explicitly for multi-RID projects).

## GitHub Actions
- Workflow builds on `ubuntu-latest` with .NET 9.
- Downloads Node archives for `win-x64`, `win-arm64`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64` (default `NODE_VERSION=22.21.1`).
- Packs all helper + native packages, uploads artifacts, and can publish on tags. Optional publish can be enabled by adding `NUGET_API_KEY` and `NUGET_SOURCE` secrets.
- If the workflow runs on a tag `vX.Y.Z`, that tag value is used as the package version; otherwise it defaults to 0.2.0.
