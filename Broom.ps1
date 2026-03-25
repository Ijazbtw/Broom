param($TargetFolder)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ================= VALIDATION =================
if (-not $TargetFolder -or -not (Test-Path $TargetFolder)) {
    [System.Windows.Forms.MessageBox]::Show("Invalid folder path.")
    exit
}

# ================= FORM =================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Broom"
$form.ClientSize = New-Object System.Drawing.Size(520,480)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $true
$form.AutoScaleMode = 'Font'

# ================= MODE GROUP =================
$modeGroup = New-Object System.Windows.Forms.GroupBox
$modeGroup.Text = "Mode"
$modeGroup.Location = New-Object System.Drawing.Point(10,10)
$modeGroup.Size = New-Object System.Drawing.Size(500,55)

$keepRadio = New-Object System.Windows.Forms.RadioButton
$keepRadio.Text = "KEEP"
$keepRadio.Location = New-Object System.Drawing.Point(15,25)
$keepRadio.Checked = $true

$removeRadio = New-Object System.Windows.Forms.RadioButton
$removeRadio.Text = "REMOVE"
$removeRadio.Location = New-Object System.Drawing.Point(180,25)

$modeGroup.Controls.AddRange(@($keepRadio, $removeRadio))

# ================= LABEL =================
$label = New-Object System.Windows.Forms.Label
$label.Text = "Names (space / new-line separated, extension ignored):"
$label.Location = New-Object System.Drawing.Point(10,75)
$label.AutoSize = $true

# ================= TEXTBOX =================
$textBox = New-Object System.Windows.Forms.TextBox
$textBox.Location = New-Object System.Drawing.Point(10,100)
$textBox.Size = New-Object System.Drawing.Size(500,70)
$textBox.Multiline = $true
$textBox.ScrollBars = 'Vertical'

# ================= LISTVIEW =================
$listView = New-Object System.Windows.Forms.ListView
$listView.Location = New-Object System.Drawing.Point(10,185)
$listView.Size = New-Object System.Drawing.Size(500,230)
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.HideSelection = $false
$listView.MultiSelect = $true
$listView.Columns.Add("Files selected", 470)

# ================= ICON LIST =================
$iconList = New-Object System.Windows.Forms.ImageList
$iconList.ImageSize = New-Object System.Drawing.Size(16,16)
$listView.SmallImageList = $iconList

# ================= BUTTON SIZE =================
$btnSize = New-Object System.Drawing.Size(140,30)

# ================= BUTTONS =================
$selectBtn = New-Object System.Windows.Forms.Button
$selectBtn.Text = "Select (Preview)"
$selectBtn.Location = New-Object System.Drawing.Point(10,430)
$selectBtn.Size = $btnSize

$moveBtn = New-Object System.Windows.Forms.Button
$moveBtn.Text = "Move to To-Delete"
$moveBtn.Location = New-Object System.Drawing.Point(190,430)
$moveBtn.Size = $btnSize

$deleteBtn = New-Object System.Windows.Forms.Button
$deleteBtn.Text = "Delete Permanently"
$deleteBtn.Location = New-Object System.Drawing.Point(360,430)
$deleteBtn.Size = $btnSize
$deleteBtn.Enabled = $false   # disabled until preview

# ================= HELPERS =================
function Get-NormalizedNames {
    return $textBox.Text -split '\s+' |
           Where-Object { $_ } |
           ForEach-Object { ($_ -split '\.')[0] }
}

function Get-FilesToProcess {
    $names = Get-NormalizedNames
    $files = Get-ChildItem -Path $TargetFolder -File

    if ($keepRadio.Checked) {
        return $files | Where-Object { $_.BaseName -notin $names }
    } else {
        return $files | Where-Object { $_.BaseName -in $names }
    }
}

function Get-MissingNames {
    $names = Get-NormalizedNames
    $existing = (Get-ChildItem -Path $TargetFolder -File).BaseName
    return $names | Where-Object { $_ -notin $existing }
}

function Show-MissingNamesWarning {
    $missing = Get-MissingNames
    if ($missing.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "These names were not found:`n`n$($missing -join "`n")",
            "Warning",
            "OK",
            "Warning"
        )
    }
}

# ================= PREVIEW =================
$selectBtn.Add_Click({
    $listView.Items.Clear()
    $iconList.Images.Clear()

    Show-MissingNamesWarning

    $files = Get-FilesToProcess
    $i = 0
    foreach ($file in $files) {
        $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($file.FullName)
        $iconList.Images.Add($icon)

        $item = New-Object System.Windows.Forms.ListViewItem($file.Name, $i)
        $item.Selected = $true
        $listView.Items.Add($item)
        $i++
    }

    # enable delete only after preview
    $deleteBtn.Enabled = $true
})

# ================= MOVE =================
$moveBtn.Add_Click({
    Show-MissingNamesWarning

    if ([System.Windows.Forms.MessageBox]::Show(
        "Selected files will be MOVED to 'To-Delete'.",
        "Confirm Move",
        "YesNo",
        "Information"
    ) -eq "Yes") {

        $toDeleteFolder = Join-Path $TargetFolder "To-Delete"
        if (-not (Test-Path $toDeleteFolder)) {
            New-Item -ItemType Directory -Path $toDeleteFolder | Out-Null
        }

        Get-FilesToProcess | Move-Item -Destination $toDeleteFolder -Force
        [System.Windows.Forms.MessageBox]::Show("Files moved successfully.")
        $form.Close()
    }
})

# ================= DELETE =================
$deleteBtn.Add_Click({
    Show-MissingNamesWarning

    if ([System.Windows.Forms.MessageBox]::Show(
        "This will PERMANENTLY delete the selected files.`n`nContinue?",
        "WARNING",
        "YesNo",
        "Warning"
    ) -eq "Yes") {

        Get-FilesToProcess | Remove-Item -Force
        [System.Windows.Forms.MessageBox]::Show("Files permanently deleted.")
        $form.Close()
    }
})

# ================= ADD CONTROLS =================
$form.Controls.AddRange(@(
    $modeGroup,
    $label,
    $textBox,
    $listView,
    $selectBtn,
    $moveBtn,
    $deleteBtn
))

# ================= RUN =================
$form.ShowDialog()
