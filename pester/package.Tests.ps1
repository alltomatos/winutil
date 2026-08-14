#===========================================================================
# Tests - Package Selection and Package Managers
#===========================================================================

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

    . (Join-Path $script:repoRoot "functions\private\Get-WinUtilSelectedPackages.ps1")
    . (Join-Path $script:repoRoot "functions\private\Test-WinUtilPackageManager.ps1")
    . (Join-Path $script:repoRoot "functions\private\Install-WinUtilProgramWinget.ps1")
    . (Join-Path $script:repoRoot "functions\private\Install-WinUtilProgramChoco.ps1")
    . (Join-Path $script:repoRoot "functions\private\Install-WinUtilProgramNpm.ps1")
    . (Join-Path $script:repoRoot "functions\private\Install-WinUtilProgramScript.ps1")

    function Invoke-WPFUIThread { }
    function Write-WinUtilLog {
        param($Message, $Level, $Component)
    }
    function Install-WinUtilWinget { }
}

Describe "Get-WinUtilSelectedPackages" {
    BeforeEach {
        Mock Invoke-WPFUIThread { }
    }

    It "uses winget IDs when winget is preferred" {
        $packages = @(
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
            [pscustomobject]@{ winget = "VideoLAN.VLC"; choco = "vlc" }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Winget"

        (@($result["Winget"]) -join "|") | Should -Be "Git.Git|VideoLAN.VLC"
        @($result["Choco"]).Count | Should -Be 0
    }

    It "routes packages with an npm ID to Npm regardless of preference" {
        $packages = @(
            [pscustomobject]@{ winget = "na"; choco = "na"; npm = "omniroute@latest" }
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Choco"

        (@($result["Npm"]) -join "|") | Should -Be "omniroute@latest"
        (@($result["Choco"]) -join "|") | Should -Be "git"
    }

    It "routes packages with a script URL to Script ahead of npm and package managers" {
        $packages = @(
            [pscustomobject]@{ winget = "na"; choco = "na"; script = "https://example.com/install.ps1" }
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Choco"

        (@($result["Script"]) -join "|") | Should -Be "https://example.com/install.ps1"
        (@($result["Choco"]) -join "|") | Should -Be "git"
    }

    It "uses choco IDs and falls back to winget for na or missing choco IDs" {
        $packages = @(
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
            [pscustomobject]@{ winget = "VideoLAN.VLC"; choco = "na" }
            [pscustomobject]@{ winget = "Mozilla.Firefox" }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Choco"

        (@($result["Choco"]) -join "|") | Should -Be "git"
        (@($result["Winget"]) -join "|") | Should -Be "VideoLAN.VLC|Mozilla.Firefox"
    }

    It "skips blank, na, and missing package IDs" {
        $packages = @(
            [pscustomobject]@{ winget = ""; choco = "" }
            [pscustomobject]@{ winget = "na"; choco = "na" }
            [pscustomobject]@{ choco = "only-choco" }
            [pscustomobject]@{ winget = "   " }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Winget"

        @($result["Winget"]).Count | Should -Be 0
        @($result["Choco"]).Count | Should -Be 0
    }

    It "deduplicates package IDs" {
        $packages = @(
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
            [pscustomobject]@{ winget = "Git.Git"; choco = "git" }
            [pscustomobject]@{ winget = "VideoLAN.VLC"; choco = "vlc" }
        )

        $result = Get-WinUtilSelectedPackages -PackageList $packages -Preference "Choco"

        (@($result["Choco"]) -join "|") | Should -Be "git|vlc"
        @($result["Winget"]).Count | Should -Be 0
    }

    It "returns empty package lists for an empty selection" {
        $result = Get-WinUtilSelectedPackages -PackageList @() -Preference "Winget"

        @($result["Winget"]).Count | Should -Be 0
        @($result["Choco"]).Count | Should -Be 0
    }
}

Describe "Test-WinUtilPackageManager" {
    BeforeEach {
        Mock Write-Host { }
    }

    It "reports winget installed when the command exists" {
        Mock Get-Command {
            [pscustomobject]@{ Name = "winget" }
        } -ParameterFilter { $Name -eq "winget" -and $ErrorAction -eq "SilentlyContinue" }

        Test-WinUtilPackageManager -winget | Should -Be "installed"

        Should -Invoke -CommandName Get-Command -Times 1 -Exactly -ParameterFilter {
            $Name -eq "winget" -and $ErrorAction -eq "SilentlyContinue"
        }
    }

    It "reports choco not installed when the command is missing" {
        Mock Get-Command {
            $null
        } -ParameterFilter { $Name -eq "choco" -and $ErrorAction -eq "SilentlyContinue" }

        Test-WinUtilPackageManager -choco | Should -Be "not-installed"

        Should -Invoke -CommandName Get-Command -Times 1 -Exactly -ParameterFilter {
            $Name -eq "choco" -and $ErrorAction -eq "SilentlyContinue"
        }
    }
}

Describe "Install-WinUtilProgramWinget" {
    BeforeEach {
        Mock Write-WinUtilLog { }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
    }

    It "starts winget with install arguments" {
        Install-WinUtilProgramWinget -Action Install -Programs @("Git.Git")

        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "winget" -and
                (@($ArgumentList) -join "|") -eq "install|--id|Git.Git|--accept-package-agreements|--accept-source-agreements|--source|winget|--silent" -and
                $NoNewWindow -eq $true -and
                $Wait -eq $true -and
                $PassThru -eq $true
        }
    }

    It "starts winget with uninstall arguments and msstore source when requested" {
        Install-WinUtilProgramWinget -Action Uninstall -Programs @("msstore:9NBLGGH4NNS1")

        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "winget" -and
                (@($ArgumentList) -join "|") -eq "uninstall|--id|9NBLGGH4NNS1|--source|msstore|--silent"
        }
    }

    It "skips whitespace and na package IDs" {
        Install-WinUtilProgramWinget -Action Install -Programs @(" ", "na")

        Should -Invoke -CommandName Start-Process -Times 0 -Exactly
    }
}

Describe "Install-WinUtilProgramChoco" {
    BeforeEach {
        Mock Write-WinUtilLog { }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
    }

    It "starts choco with install arguments" {
        Install-WinUtilProgramChoco -Action Install -Programs @("git", "vlc")

        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "choco" -and
                $ArgumentList -eq "install git vlc -y" -and
                $NoNewWindow -eq $true -and
                $Wait -eq $true -and
                $PassThru -eq $true
        }
    }

    It "starts choco with uninstall arguments" {
        Install-WinUtilProgramChoco -Action Uninstall -Programs @("git")

        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "choco" -and $ArgumentList -eq "uninstall git -y"
        }
    }
}

Describe "Install-WinUtilProgramNpm" {
    BeforeEach {
        Mock Write-WinUtilLog { }
        Mock Install-WinUtilWinget { }
        Mock Install-WinUtilProgramWinget { }
        Mock Start-Process { [pscustomobject]@{ ExitCode = 0 } }
        Mock Get-ExecutionPolicy { 'RemoteSigned' } -ParameterFilter { $Scope -eq 'CurrentUser' }
        Mock Set-ExecutionPolicy { }
    }

    It "starts npm with install arguments when npm is already on PATH" {
        Mock Get-Command { [pscustomobject]@{ Name = "npm" } } -ParameterFilter { $Name -eq "npm" }

        Install-WinUtilProgramNpm -Action Install -Programs @("omniroute@latest")

        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "npm.cmd" -and
                (@($ArgumentList) -join "|") -eq "install|-g|omniroute@latest" -and
                $NoNewWindow -eq $true -and
                $Wait -eq $true -and
                $PassThru -eq $true
        }
        Should -Invoke -CommandName Install-WinUtilProgramWinget -Times 0 -Exactly
    }

    It "installs Node.js LTS via winget first when npm is missing" {
        Mock Get-Command { $null } -ParameterFilter { $Name -eq "npm" }

        Install-WinUtilProgramNpm -Action Install -Programs @("omniroute@latest")

        Should -Invoke -CommandName Install-WinUtilProgramWinget -Times 1 -Exactly -ParameterFilter {
            $Action -eq "Install" -and (@($Programs) -join "|") -eq "OpenJS.NodeJS.LTS"
        }
        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "npm.cmd" -and (@($ArgumentList) -join "|") -eq "install|-g|omniroute@latest"
        }
    }

    It "starts npm with uninstall arguments and does not check for a Node prerequisite" {
        Install-WinUtilProgramNpm -Action Uninstall -Programs @("omniroute@latest")

        Should -Invoke -CommandName Install-WinUtilProgramWinget -Times 0 -Exactly
        Should -Invoke -CommandName Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "npm.cmd" -and (@($ArgumentList) -join "|") -eq "uninstall|-g|omniroute@latest"
        }
    }

    It "skips blank and na package IDs" {
        Install-WinUtilProgramNpm -Action Install -Programs @(" ", "na")

        Should -Invoke -CommandName Start-Process -Times 0 -Exactly
        Should -Invoke -CommandName Install-WinUtilProgramWinget -Times 0 -Exactly
    }

    It "relaxes a Restricted CurrentUser execution policy so npm's .ps1 shims can run" {
        Mock Get-Command { [pscustomobject]@{ Name = "npm" } } -ParameterFilter { $Name -eq "npm" }
        Mock Get-ExecutionPolicy { 'Restricted' } -ParameterFilter { $Scope -eq 'CurrentUser' }

        Install-WinUtilProgramNpm -Action Install -Programs @("omniroute@latest")

        Should -Invoke -CommandName Set-ExecutionPolicy -Times 1 -Exactly -ParameterFilter {
            $Scope -eq 'CurrentUser' -and $ExecutionPolicy -eq 'RemoteSigned' -and $Force -eq $true
        }
    }

    It "leaves an already-permissive CurrentUser execution policy alone" {
        Mock Get-Command { [pscustomobject]@{ Name = "npm" } } -ParameterFilter { $Name -eq "npm" }
        Mock Get-ExecutionPolicy { 'Unrestricted' } -ParameterFilter { $Scope -eq 'CurrentUser' }

        Install-WinUtilProgramNpm -Action Install -Programs @("omniroute@latest")

        Should -Invoke -CommandName Set-ExecutionPolicy -Times 0 -Exactly
    }

    It "does not touch the execution policy on uninstall" {
        Install-WinUtilProgramNpm -Action Uninstall -Programs @("omniroute@latest")

        Should -Invoke -CommandName Get-ExecutionPolicy -Times 0 -Exactly
        Should -Invoke -CommandName Set-ExecutionPolicy -Times 0 -Exactly
    }
}

Describe "Install-WinUtilProgramScript" {
    BeforeEach {
        Mock Write-WinUtilLog { }
        Mock Invoke-RestMethod { "# fake script content" }
        Mock Invoke-Expression { }
    }

    It "downloads and executes the install script on Install" {
        Install-WinUtilProgramScript -Action Install -Programs @("https://example.com/install.ps1")

        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq "https://example.com/install.ps1"
        }
        Should -Invoke -CommandName Invoke-Expression -Times 1 -Exactly
    }

    It "does not download or execute anything on Uninstall, only logs" {
        Install-WinUtilProgramScript -Action Uninstall -Programs @("https://example.com/install.ps1")

        Should -Invoke -CommandName Invoke-RestMethod -Times 0 -Exactly
        Should -Invoke -CommandName Invoke-Expression -Times 0 -Exactly
        Should -Invoke -CommandName Write-WinUtilLog -Times 1 -Exactly -ParameterFilter {
            $Level -eq "WARN"
        }
    }

    It "skips blank and na entries" {
        Install-WinUtilProgramScript -Action Install -Programs @(" ", "na")

        Should -Invoke -CommandName Invoke-RestMethod -Times 0 -Exactly
    }

    It "logs an error and continues past a failed script instead of throwing" {
        Mock Invoke-RestMethod { throw "network error" }

        { Install-WinUtilProgramScript -Action Install -Programs @("https://example.com/install.ps1") } | Should -Not -Throw

        Should -Invoke -CommandName Write-WinUtilLog -Times 1 -Exactly -ParameterFilter {
            $Level -eq "ERROR"
        }
    }
}
