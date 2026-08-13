function Invoke-WPFSelectAllApps {
    <#
        .SYNOPSIS
            Selects every Install tab app that is currently visible

        .DESCRIPTION
            Respects whatever the search box and category chips are currently filtering to, so
            "select all" means all matches, not the entire catalog. Checking each checkbox fires
            its own Add_Checked handler, which is what actually updates $sync.selectedApps and the
            Selected Apps menu.
    #>
    if ($null -eq $sync.ItemsControl) {
        return
    }

    foreach ($category in $sync.ItemsControl.Items) {
        if ($category.Children.Count -lt 2) {
            continue
        }

        $wrapPanel = $category.Children[1]
        foreach ($appControl in $wrapPanel.Children) {
            if ($appControl -is [System.Windows.Controls.CheckBox] -and $appControl.Visibility -eq [Windows.Visibility]::Visible) {
                $appControl.IsChecked = $true
            }
        }
    }
}
