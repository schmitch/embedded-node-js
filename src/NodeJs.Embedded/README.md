# Embedded Node.js

NuGet package that ships prebuilt Node.js executables for Windows, Linux, and macOS (x64/arm64). It removes the requirement for a machine-level Node installation and is intended to be used together with `JavaScriptEngineSwitcher.Node` or any host that needs a portable `node` binary.

## Installing
Add the package reference (with a single `RuntimeIdentifier` set, the correct native package is pulled automatically):
```xml
<PackageReference Include="EmbeddedNodeJs" Version="0.2.0" />
```

Resolve the embedded executable path and pass it to your `JavaScriptEngineSwitcher.Node` settings:
```csharp
using JavaScriptEngineSwitcher.Node;
using NodeJs.Embedded;

var settings = new NodeSettings
{
    EngineExecutablePath = NodeRuntimeLocator.GetNodeExecutablePath()
};
```

## Building locally
```bash
# Fetch Node distributions into runtimes/<rid>/native/ for each native package
./scripts/download-node.sh 22.21.1

# Pack helper + native packages
dotnet pack src/NodeJs.Embedded/NodeJs.Embedded.csproj -c Release
for proj in src/NodeJs.Embedded.Native.*/NodeJs.Embedded.Native.*.csproj; do
  dotnet pack "$proj" -c Release
done
```

## Multi-RID projects
If your project targets multiple RIDs, explicitly include the matching native packages with conditions:
```xml
<ItemGroup Condition="'$(RuntimeIdentifier)'=='linux-x64'">
  <PackageReference Include="EmbeddedNodeJs.Native.linux-x64" Version="0.2.0" />
</ItemGroup>
<ItemGroup Condition="'$(RuntimeIdentifier)'=='win-x64'">
  <PackageReference Include="EmbeddedNodeJs.Native.win-x64" Version="0.2.0" />
</ItemGroup>
<!-- add more RIDs as needed -->
```

## License
The helper library is MIT licensed. Node.js binaries are provided under the Node.js license; the download script copies the upstream `LICENSE` file alongside each embedded binary.
