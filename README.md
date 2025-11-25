# Embedded Node.js NuGet

This repository builds a NuGet package that bundles prebuilt Node.js executables for Windows, Linux, and macOS (x64/arm64) so consumers such as `JavaScriptEngineSwitcher.Node` can run without depending on a machine-wide Node.js installation.

## Project layout
- `src/NodeJs.Embedded`: Packaging project and helper API to resolve the embedded Node binary.
- `scripts/download-node.sh`: Utility that downloads platform archives from `nodejs.org`, extracts the `node` executable, and populates `runtimes/<rid>/native/`.
- `.github/workflows/publish.yml`: GitHub Actions workflow that fetches Node binaries, packs, and can publish the NuGet package.

## Local workflow
```bash
# Fetch Node distributions (customize NODE_VERSION as needed)
./scripts/download-node.sh 20.12.2

# Pack the NuGet (outputs to bin/Debug and bin/Debug/EmbeddedNodeJs.0.1.0.nupkg)
dotnet pack src/NodeJs.Embedded/NodeJs.Embedded.csproj -c Release
```

## Using with JavaScriptEngineSwitcher.Node
1. Add package references:
   ```xml
   <PackageReference Include="JavaScriptEngineSwitcher.Node" Version="*-use-your-version*" />
   <PackageReference Include="EmbeddedNodeJs" Version="0.1.0" />
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
3. The runtime-specific `node`/`node.exe` is copied automatically from `runtimes/<rid>/native/` into your build output when referencing the package.

## GitHub Actions
- Workflow builds on `ubuntu-latest`.
- Downloads Node archives for `win-x64`, `win-arm64`, `linux-x64`, `linux-arm64`, `osx-x64`, `osx-arm64`.
- Produces `.nupkg`/`.snupkg`. Optional publish can be enabled by adding `NUGET_API_KEY` and `NUGET_SOURCE` secrets.
