using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;

namespace NodeJs.Embedded;

/// <summary>
/// Resolves the embedded Node.js executable path for the current platform.
/// </summary>
public static class NodeRuntimeLocator
{
    private static readonly Dictionary<(OSPlatform, Architecture), string> RidMap = new()
    {
        { (OSPlatform.Windows, Architecture.X64), "win-x64" },
        { (OSPlatform.Windows, Architecture.Arm64), "win-arm64" },
        { (OSPlatform.Linux, Architecture.X64), "linux-x64" },
        { (OSPlatform.Linux, Architecture.Arm64), "linux-arm64" },
        { (OSPlatform.OSX, Architecture.X64), "osx-x64" },
        { (OSPlatform.OSX, Architecture.Arm64), "osx-arm64" }
    };

    private static readonly string[] KnownRids =
    {
        "win-x64",
        "win-arm64",
        "linux-x64",
        "linux-arm64",
        "osx-x64",
        "osx-arm64"
    };

    /// <summary>
    /// Returns the full path to the embedded Node.js executable for the current RID.
    /// </summary>
    public static string GetNodeExecutablePath()
    {
        var rid = ResolveRuntimeIdentifier();
        var fileName = RuntimeInformation.IsOSPlatform(OSPlatform.Windows) ? "node.exe" : "node";

        var candidate = Path.Combine(AppContext.BaseDirectory, "runtimes", rid, "native", fileName);
        if (File.Exists(candidate))
        {
            return candidate;
        }

        throw new InvalidOperationException(
            $"Embedded Node.js binary for RID '{rid}' was not found. Checked '{candidate}'. " +
            $"Available RIDs: {string.Join(", ", KnownRids)}");
    }

    private static string ResolveRuntimeIdentifier()
    {
        foreach (var kvp in RidMap)
        {
            if (RuntimeInformation.IsOSPlatform(kvp.Key.Item1) &&
                RuntimeInformation.ProcessArchitecture == kvp.Key.Item2)
            {
                return kvp.Value;
            }
        }

        var runtimeIdentifier = RuntimeInformation.RuntimeIdentifier;
        foreach (var rid in KnownRids)
        {
            if (runtimeIdentifier.StartsWith(rid, StringComparison.OrdinalIgnoreCase))
            {
                return rid;
            }
        }

        throw new PlatformNotSupportedException(
            $"No embedded Node.js binary is defined for OS '{RuntimeInformation.OSDescription}' " +
            $"and architecture '{RuntimeInformation.ProcessArchitecture}'.");
    }
}
