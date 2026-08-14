Function Install-WinUtilProgramNpm {
    <#
        .SYNOPSIS
            Installs or uninstalls npm-distributed packages globally

        .DESCRIPTION
            npm packages need a Node.js runtime, which none of the other install sources
            provide. On install, if npm isn't on PATH yet, this installs Node.js LTS via
            winget first so the npm install below has something to run against.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("Install", "Uninstall")]
        [string]$Action,

        [Parameter(Mandatory=$true)]
        [string[]]$Programs
    )

    $packages = @($Programs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "na" })
    if ($packages.Count -eq 0) {
        return
    }

    if ($Action -eq 'Install' -and -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-WinUtilLog -Component "Package" -Message "npm not found on PATH, installing Node.js LTS as a prerequisite"
        Install-WinUtilWinget
        Install-WinUtilProgramWinget -Action Install -Programs @("OpenJS.NodeJS.LTS")

        # winget updates the Machine/User PATH in the registry, but this already-running
        # process's own $env:Path is a snapshot from when it started, so npm still won't
        # resolve until that snapshot is refreshed from the registry.
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            Write-WinUtilLog -Level "WARN" -Component "Package" -Message "npm still not found on PATH after installing Node.js LTS and refreshing PATH. A terminal restart may be required."
        }
    }

    $verb = if ($Action -eq 'Install') { "install" } else { "uninstall" }

    foreach ($program in $packages) {
        $arguments = @($verb, "-g", $program)

        Write-WinUtilLog -Component "Package" -Message "$Action npm package: $program"
        # npm.cmd, not npm: Start-Process launches the file directly rather than through
        # cmd.exe, and the extensionless "npm" on PATH is a POSIX shell shim, not a PE
        # binary Windows can execute - that fails with "not a valid Win32 application".
        $process = Start-Process -FilePath "npm.cmd" -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        Write-WinUtilLog -Component "Package" -Message "$Action npm package completed: $program (exit code: $($process.ExitCode))"
    }
}
