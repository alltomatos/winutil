Function Install-WinUtilProgramScript {
    <#
        .SYNOPSIS
            Installs packages distributed only as a remote install script (no winget/choco/npm)

        .DESCRIPTION
            Unlike winget/choco/npm, there's no package manager backing this - the "package ID"
            is the script's URL, and installing means downloading and executing it directly.
            Invoke-WPFInstall confirms this with the user before packages ever reach here, since
            it's meaningfully more trust than resolving a vetted package manager entry.
            There is no generic way to uninstall something a third-party script installed, so
            Uninstall only logs a pointer to do it manually.
    #>
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("Install", "Uninstall")]
        [string]$Action,

        [Parameter(Mandatory=$true)]
        [string[]]$Programs
    )

    $urls = @($Programs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne "na" })
    if ($urls.Count -eq 0) {
        return
    }

    if ($Action -eq 'Uninstall') {
        foreach ($url in $urls) {
            Write-WinUtilLog -Level "WARN" -Component "Package" -Message "Script-installed package ($url) has no automated uninstall; remove it manually."
        }
        return
    }

    foreach ($url in $urls) {
        Write-WinUtilLog -Component "Package" -Message "Install script package: $url"
        try {
            Invoke-Expression (Invoke-RestMethod -Uri $url)
            Write-WinUtilLog -Component "Package" -Message "Install script package completed: $url"
        } catch {
            Write-WinUtilLog -Level "ERROR" -Component "Package" -Message "Install script package failed: $url ($($_.Exception.Message))"
        }
    }
}
