function Invoke-WinUtilInstallAppRenderBatch {
    param(
        [Parameter(Mandatory = $true)]
        $CategoryBatch
    )

    if ($CategoryBatch.Subcategory) {
        $subHeader = New-Object Windows.Controls.Label
        # Content is the display name (ordering prefix stripped); Tag keeps the raw key so
        # Find-AppsByNameOrDescription can match it against $appEntry.Subcategory exactly.
        $subHeader.Content = $CategoryBatch.Subcategory -replace '^\d+\s*-\s*', ''
        $subHeader.Tag = "SubcategoryHeader:$($CategoryBatch.Subcategory)"
        $subHeader.FontWeight = "Bold"
        $subHeader.SetResourceReference([Windows.Controls.Control]::FontSizeProperty, "FontSize")
        $subHeader.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, "LabelboxForegroundColor")
        $subHeader.Margin = New-Object Windows.Thickness(0, 8, 0, 2)
        [System.Windows.Automation.AutomationProperties]::SetName($subHeader, $subHeader.Content)

        # Bind Width to the WrapPanel's ActualWidth to force a full-row line break, same trick
        # Initialize-InstallCategoryAppList uses to keep the category header on its own row.
        $subHeaderBinding = New-Object Windows.Data.Binding
        $subHeaderBinding.Path = New-Object Windows.PropertyPath("ActualWidth")
        $subHeaderBinding.RelativeSource = New-Object Windows.Data.RelativeSource([Windows.Data.RelativeSourceMode]::FindAncestor, [Windows.Controls.WrapPanel], 1)
        [void][Windows.Data.BindingOperations]::SetBinding($subHeader, [Windows.FrameworkElement]::WidthProperty, $subHeaderBinding)

        $null = $CategoryBatch.TargetElement.Children.Add($subHeader)
    }

    foreach ($appKey in $CategoryBatch.AppKeys) {
        $sync.$appKey = Initialize-InstallAppEntry -TargetElement $CategoryBatch.TargetElement -AppKey $appKey
    }

    # Entries render in batches, so a filter that is already active has to be applied to each new
    # batch. Categories count as an active filter just like search text does.
    if ($sync.currentTab -eq "Install" -and $sync.SearchBar) {
        $selectedCategories = if ($sync.SelectedAppCategories) { $sync.SelectedAppCategories.ToArray() } else { @() }

        if (-not [string]::IsNullOrWhiteSpace($sync.SearchBar.Text) -or $selectedCategories.Count -gt 0) {
            Find-AppsByNameOrDescription -SearchString $sync.SearchBar.Text -Categories $selectedCategories
        }
    }
}

function Complete-WinUtilInstallAppRendering {
    $sync.InstallAppEntriesRendered = $true
}

function Invoke-WinUtilInstallAppRenderNextBatch {
    if ($sync.InstallAppRenderQueue.Count -gt 0) {
        $categoryBatch = $sync.InstallAppRenderQueue.Dequeue()
        Invoke-WinUtilInstallAppRenderBatch -CategoryBatch $categoryBatch
    }

    if ($sync.InstallAppRenderQueue.Count -gt 0) {
        $sync.Form.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{ Invoke-WinUtilInstallAppRenderNextBatch }
        ) | Out-Null
        return
    }

    Complete-WinUtilInstallAppRendering
}

function Start-WinUtilInstallAppRendering {
    if ($null -eq $sync.InstallAppRenderQueue) {
        return
    }

    $sync.InstallAppEntriesRendered = $false

    if ($sync.Form -and $sync.Form.Dispatcher) {
        $sync.Form.Dispatcher.BeginInvoke(
            [System.Windows.Threading.DispatcherPriority]::Background,
            [action]{ Invoke-WinUtilInstallAppRenderNextBatch }
        ) | Out-Null
        return
    }

    while ($sync.InstallAppRenderQueue.Count -gt 0) {
        $categoryBatch = $sync.InstallAppRenderQueue.Dequeue()
        Invoke-WinUtilInstallAppRenderBatch -CategoryBatch $categoryBatch
    }

    Complete-WinUtilInstallAppRendering
}
