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
    }

    $verb = if ($Action -eq 'Install') { "install" } else { "uninstall" }

    foreach ($program in $packages) {
        $arguments = @($verb, "-g", $program)

        Write-WinUtilLog -Component "Package" -Message "$Action npm package: $program"
        $process = Start-Process -FilePath npm -ArgumentList $arguments -NoNewWindow -Wait -PassThru
        Write-WinUtilLog -Component "Package" -Message "$Action npm package completed: $program (exit code: $($process.ExitCode))"
    }
}
