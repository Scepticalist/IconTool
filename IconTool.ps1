################################################################################
#                                                                              #
#                               Icon Tool GUI                                  #
#                                                                              #
################################################################################
#                                                                              #
#              Extracts and exports icons/images to various formats            #
#                                                                              #
################################################################################
#
#  Based on PS scripts, modules and associated work by:
#  Boe Prox         https://learn-powershell.net/about/
#  Chrissy LeMaire  
#  Thomas Levesque  http://bit.ly/1KmLgyN
#  Darkfall         http://git.io/vZxRK 
#
#  Forms implementation and additional work by:
#  Sceptico         http://sceptico.wordpress.com
#
################################################################################
#
#   11/01/20    v0.76   Non-square exports working for bitmaps
#               v0.80   Image resizing
#               v0.81   Tidy code
#                       Fix small bug in B64 export
#   14/01/20    v0.85   Fix bug in resetting app for new images
#                       Set up tab order
#                       Fix bug in tall image icon export
#
################################################################################
#
#
$Version = 'v0.85'
#
Try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    [Windows.Forms.Application]::EnableVisualStyles()
}
Catch {
    $_.Exception.Message
    Pause
    Break
}
#Region IconExtrator
$code = '
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.IO;

namespace System {
    public class IconExtractor {
        public static Icon Extract(string file, int number, bool largeIcon) {
            IntPtr large;
            IntPtr small;
            ExtractIconEx(file, number, out large, out small, 1);
            try  { return Icon.FromHandle(largeIcon ? large : small); }
            catch  { return null; }
        }
        [DllImport("Shell32.dll", EntryPoint = "ExtractIconExW", CharSet = CharSet.Unicode, ExactSpelling = true, CallingConvention = CallingConvention.StdCall)]
        private static extern int ExtractIconEx(string sFile, int iIndex, out IntPtr piLargeVersion, out IntPtr piSmallVersion, int amountIcons);
    }
}

public class PngIconConverter
{
    public static bool Convert(System.IO.Stream input_stream, System.IO.Stream output_stream, int size, bool keep_aspect_ratio = false)
    {
        System.Drawing.Bitmap input_bit = (System.Drawing.Bitmap)System.Drawing.Bitmap.FromStream(input_stream);
        if (input_bit != null)
        {
            int width, height;
            if (keep_aspect_ratio)
            {
                width = size;
                height = input_bit.Height / input_bit.Width * size;
            }
            else
            {
                width = height = size;
            }
            System.Drawing.Bitmap new_bit = new System.Drawing.Bitmap(input_bit, new System.Drawing.Size(width, height));
            if (new_bit != null)
            {
                System.IO.MemoryStream mem_data = new System.IO.MemoryStream();
                new_bit.Save(mem_data, System.Drawing.Imaging.ImageFormat.Png);

                System.IO.BinaryWriter icon_writer = new System.IO.BinaryWriter(output_stream);
                if (output_stream != null && icon_writer != null)
                {
                    icon_writer.Write((byte)0);
                    icon_writer.Write((byte)0);
                    icon_writer.Write((short)1);
                    icon_writer.Write((short)1);
                    icon_writer.Write((byte)width);
                    icon_writer.Write((byte)height);
                    icon_writer.Write((byte)0);
                    icon_writer.Write((byte)0);
                    icon_writer.Write((short)0);
                    icon_writer.Write((short)32);
                    icon_writer.Write((int)mem_data.Length);
                    icon_writer.Write((int)(6 + 16));
                    icon_writer.Write(mem_data.ToArray());
                    icon_writer.Flush();
                    return true;
                }
            }
            return false;
        }
        return false;
    }

    public static bool Convert(string input_image, string output_icon, int size, bool keep_aspect_ratio = false)
    {
        System.IO.FileStream input_stream = new System.IO.FileStream(input_image, System.IO.FileMode.Open);
        System.IO.FileStream output_stream = new System.IO.FileStream(output_icon, System.IO.FileMode.OpenOrCreate);

        bool result = Convert(input_stream, output_stream, size, keep_aspect_ratio);

        input_stream.Close();
        output_stream.Close();

        return result;
    }
}
'
#EndRegion IconExtractor
# Add IconExtrator class
    Try {
        Add-Type -TypeDefinition $code -ReferencedAssemblies System.Drawing, System.IO -ErrorAction Stop
    }
    Catch {
        $_
        Pause
        Break
    }
#
#Region B64Images
$DasImage = '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
'
#
$AppIcon = 'AAABAAEAICAQNgAAAADoAgAAFgAAACgAAAAgAAAAQAAAAAEABAAAAAAAgAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACAAAAAgIAAgAAAAIAAgACAgAAAgICAAMDAwAAAAP8AAP8AAAD//wD/AAAA/wD/AP//AAD///8AAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHMzMzMzMzMzMzMzMzMzMzB/uLi4uLi4uLi4uLi4uLgwf4uLi4uE7ECLHZELi4uLMH+4uLi4tOxAuB2RCLi4uDB/i4uLi4TsQIsdkQuLi4sw
f7i4uLi0jsC4H4kIuLi4MH+Li4uLi0RLi4ERi4uLizB/uLi4uLgICLi3gLi4uLgwf4uLi4uLCAuLh4CLi4uLMH+4uLi4uAgIuLeAuLi4uDB/i4uAC4AIAIuAAIuLi4swf7i4d3AHeHcABwC4uLi4MH+Li3iHeIiId38Ai4uLizB/uLh/j/iI
iIjwgLi4uLgwf4uLf/d/////CIcLi4uLMH+4uLd4t3d3d3iHCLi4uDB/i4uLi4uLi4t4hwuLi4swf7i4uLi4uLi4f4cIuLi4MH+Li4uLi4uLi3d3C4uLizB/uLi4uLi4uLi4uLi4uLgwf///////////////////AHiIiIiIiIiId3d3d3d3
dwAH+4uLi4uLhwAAAAAAAAAAAH+4uLi4uHAAAAAAAAAAAAAH//////cAAAAAAAAAAAAAAHd3d3dwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD///////////////+AAAABAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAA4AA///AAf//4AP///AH/////////////w=='
#EndRegion B64Images
#
# Convert Base64 data back to object
Function Get-ImgStreamFromB64 ($B64Img) {
    $Bytes = [Convert]::FromBase64String($B64Img)
    $stream = New-Object IO.MemoryStream($Bytes, 0, $Bytes.Length)
    $stream.Write($Bytes, 0, $Bytes.Length);
    Return $stream
}
#
$MyImg = New-Object System.Drawing.Bitmap -Argument (Get-ImgStreamFromB64 $DASImage)
$MyIcon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument (Get-ImgStreamFromB64 $AppIcon)).GetHIcon())
#
$DefaultFont = New-Object System.Drawing.Font("Segoe", 8)
#
$ValidFileTypes = 'ico','bmp','png','jpg','jpeg','gif','emf','exif','tiff','wmf'
$ValidIcoSizes = '8','16','24','32','48','64','96','128'
#
Function Select-Folder ($RootFolder) {
	$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
	$FolderBrowser.Description = 'Select a folder'
	$FolderBrowser.ShowNewFolderButton = $false
	$FolderBrowser.SelectedPath = $RootFolder
	$result = $FolderBrowser.ShowDialog((New-Object System.Windows.Forms.Form -Property @{TopMost = $true }))
	If ($result -eq [Windows.Forms.DialogResult]::OK){
			$FolderBrowser.SelectedPath
	}
	Else {
			Return 'Invalid Path'
			exit
	}
}
#
#Region FormElements
$form = New-Object System.Windows.Forms.Form
$form.Font = $DefaultFont
$form.Text = "IconTool - $Version"
$form.MinimumSize = '525,675'
$form.MaximumSize = '525,1400'
$form.StartPosition = 'CenterScreen'
$form.MaximizeBox = $false
$form.Icon = $MyIcon
#
#Autoscaling settings
$form.AutoScale = $true
$form.AutoScaleMode = "Font"
#
# File selection #
$InputGrpBox = New-Object System.Windows.Forms.GroupBox
$InputGrpBox.Location = '15,20'
$InputGrpBox.Size = '230,95'
$InputGrpBox.Text = 'Browse to file/image for icon(s)'
$InputGrpBox.TabIndex = 1
# Zone Dropdown
$InputFile = New-Object System.Windows.Forms.TextBox
$InputFile.Location = '10,25'
$InputFile.Size = '210,19'
$InputFile.ReadOnly = $true
$InputFile.Enabled = $false
$InputFile.TabStop = $false
#
$BrowseBtn = New-Object System.Windows.Forms.Button
$BrowseBtn.Location = '135,55'
$BrowseBtn.Size = '80,27'
$BrowseBtn.Text = 'Browse'
$BrowseBtn.TabStop = $true
$BrowseBtn.TabIndex = 1
#
#
# Branding image for form
$DASImage = New-Object System.Windows.Forms.PictureBox
$DASImage.Width = $MyImg.Width
$DASImage.Height = $MyImg.Height
$DASImage.Location = New-Object System.Drawing.Point(($form.Width - $MyImg.Width - 30), (10))
$DASImage.Image = $MyImg
$DASImage.Anchor = 'Top,Right'
#
#
# List of icons in source file
$IconList = New-Object System.Windows.Forms.DataGridView
$IconList.RowHeadersVisible = $false
$IconList.ColumnHeadersVisible = $true
$IconList.AllowUserToAddRows = $false
$IconList.ReadOnly = $true
$IconList.SelectionMode = 'FullRowSelect'
$IconList.RowTemplate.Height = 64
$IconList.MultiSelect = $false
$IcListImage = New-Object System.Windows.Forms.DataGridViewImageColumn
$IcListImage.Name = 'IconImage'
$IconList.ColumnCount = 1
$IconList.Columns[0].Name = 'Index'
$IconList.Columns[0].DefaultCellStyle.Alignment = 'MiddleCenter'
$IconList.Columns[0].AutoSizeMode = 'ColumnHeader'
$IconList.Columns.Add($IcListImage) | Out-Null
$IconList.Columns[1].AutoSizeMode = 'Fill'
$IconList.Location = '15,125'
$IconList.Size = '203,369'
$IconList.Anchor = 'Top,Left,Bottom'
$IconList.TabIndex = 2
$IconList.TabStop = $true
#
#
# Groupbox for export path
$ExpPathGrp = New-Object System.Windows.Forms.GroupBox
$ExpPathGrp.Location = '225,125'
$ExpPathGrp.Size = '270,54'
$ExpPathGrp.Text = 'Select path for exported data/file'
$ExpPathGrp.Enabled = $false
$ExpPathGrp.TabIndex = 3
#
$ExportText = New-Object System.Windows.Forms.Label
$ExportText.Location = '10,23'
$ExportText.Size = '155,19'
$ExportText.AutoEllipsis = $true
$ExportText.Text = "$env:USERPROFILE\Downloads"
#
$ExportPathBtn = New-Object System.Windows.Forms.Button
$ExportPathBtn.Location = '175,16'
$ExportPathBtn.Size = '80,27'
$ExportPathBtn.Text = 'Browse'
$ExportPathBtn.Enabled = $true
$ExportPathBtn.TabStop = $true
$ExportPathBtn.TabIndex = 1
#
#
# Groupbox for icon sources
$ExportGrpBox = New-Object System.Windows.Forms.GroupBox
$ExportGrpBox.Location = '225,185'
$ExportGrpBox.Size = '270,310'
$ExportGrpBox.Text = 'Export selected item to required format'
$ExportGrpBox.Enabled = $false
$ExportGrpBox.TabIndex = 4
$ExportGrpBox.Anchor = 'Top,Right'
#
$B64RadioBtn = New-Object System.Windows.Forms.RadioButton
$B64RadioBtn.Location = '10,25'
$B64RadioBtn.Size = '160,17'
$B64RadioBtn.Text = "Convert to Base64 string"
$B64RadioBtn.Checked = $true
$B64RadioBtn.TabStop = $true
$B64RadioBtn.TabIndex = 1
#
$B64ExportType = New-Object System.Windows.Forms.CheckBox
$B64ExportType.Location = '30,45'
$B64ExportType.Size = '200,19'
$B64ExportType.Text = 'Include code examples for PS Forms'
$B64ExportType.TextAlign = 'BottomLeft'
$B64ExportType.TabIndex = 2
#
$B64Format = New-Object System.Windows.Forms.CheckBox
$B64Format.Location = '30,65'
$B64Format.Size = '200,19'
$B64Format.Text = 'Format Base64 for legibility:'
$B64Format.TextAlign = 'BottomLeft'
$B64Format.Checked = $true
$B64Format.TabIndex = 3
#
$FormatLines = New-Object System.Windows.Forms.ComboBox
$FormatLines.Location = '53,88'
$FormatLines.Size = '60,30'
$FormatLines.Enabled = $true
$FormatLines.Items.AddRange(@('100','120','140','160','180','200'))
$FormatLines.SelectedIndex = 3
$FormatLines.TabIndex = 4
#
$FormatLabel = New-Object System.Windows.Forms.Label
$FormatLabel.Location = '120,91'
$FormatLabel.Size = '160,17'
$FormatLabel.Text = 'characters per line'
#
$ExportRadioBtn = New-Object System.Windows.Forms.RadioButton
$ExportRadioBtn.Location = '10,122'
$ExportRadioBtn.Size = '140,17'
$ExportRadioBtn.Text = "Save to image file"
$ExportRadioBtn.TabStop = $true
$ExportRadioBtn.TabIndex = 5
#
$ExpText = New-Object System.Windows.Forms.Label
$ExpText.Location = '30,148'
$ExpText.Size = '140,17'
$ExpText.Text = 'Filetype:'
#
$ExportFormat = New-Object System.Windows.Forms.ComboBox
$ExportFormat.Location = '100,145'
$ExportFormat.Size = '60,30'
$ExportFormat.Items.AddRange($ValidFileTypes)
$ExportFormat.SelectedIndex = 0
$ExportFormat.Enabled = $false
$ExportFormat.TabIndex = 6
$ExportFormat.TabStop = $true
#
$ExpText = New-Object System.Windows.Forms.Label
$ExpText.Location = '30,148'
$ExpText.Size = '70,17'
$ExpText.Text = 'File Type:'
#
$ImgSize = New-Object System.Windows.Forms.ComboBox
$ImgSize.Location = '100,175'
$ImgSize.Size = '60,25'
$ImgSize.Items.AddRange($ValidIcoSizes)
$ImgSize.SelectedIndex = 3
$ImgSize.Enabled = $false
$ImgSize.TabIndex = 7
$ImgSize.TabStop = $true
#
$IcnText = New-Object System.Windows.Forms.Label
$IcnText.Location = '30,178'
$IcnText.Size = '70,17'
$IcnText.Text = 'Icon Size:'
#
$ImgText = New-Object System.Windows.Forms.Label
$ImgText.Location = '30,208'
$ImgText.Size = '70,17'
$ImgText.Text = 'Image Size:'
#
$ImgX = New-Object System.Windows.Forms.TextBox
$ImgX.Location = '100,205'
$ImgX.Size = '50,19'
$imgX.TextAlign = 'Center'
$ImgX.Enabled = $false
$ImgX.TabIndex = 8
#
$ImgSep = New-Object System.Windows.Forms.Label
$ImgSep.Location = '155,208'
$ImgSep.Size = '15,17'
$ImgSep.Text = 'x'
#
$ImgY = New-Object System.Windows.Forms.TextBox
$ImgY.Location = '170,205'
$ImgY.Size = '50,19'
$ImgY.TextAlign = 'Center'
$ImgY.Enabled = $false
$ImgY.TabIndex = 9
#
$ExportBtn = New-Object System.Windows.Forms.Button
$ExportBtn.Location = '155,265'
$ExportBtn.Size = '100,32'
$ExportBtn.Text = 'Export Data/File'
$ExportBtn.Enabled = $true
$ExportBtn.TabStop = $true
$ExportBtn.TabIndex = 10
#
#
# Info/Log window
$LoggingText = New-Object System.Windows.Forms.TextBox
$LoggingText.Location = '15,505'
$LoggingText.Size = '480,120'
$LoggingText.Enabled = $true
$LoggingText.Multiline = $true
$LoggingText.ScrollBars = "Vertical"
$LoggingText.ReadOnly = $true
$LoggingText.Anchor = 'Bottom,Left'
$LoggingText.TabStop = $false
#
#
# Add objects to form
$InputGrpBox.Controls.AddRange(@($InputFile,$BrowseBtn))
$ExpPathGrp.Controls.AddRange(@($ExportText,$ExportPathBtn))
$ExportGrpBox.Controls.AddRange(@($ExportFormat,$B64RadioBtn,$ExpText,$B64ExportType,$B64Format,$FormatLines,$FormatLabel,$ExportRadioBtn,$ImgSize,$IcnText,$ImgText,$ImgX,$ImgSep,$ImgY,$ExportBtn))
$form.Controls.AddRange(@($InputGrpBox,$DASImage,$IconList,$ExpPathGrp,$ExportGrpBox,$LoggingText))
#
#EndRegion FormElements
#
# File browser dialog
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
$FileBrowser.title = "Pick image or icon source file"
$FileBrowser.filter = "Image File | *.ico;*.bmp;*.png;*.jpg;*.jpeg;*.gif;*.emf;*.exif;*.tiff;*.wmf | Icon Source | *.exe;*.dll;*.icl"
#
Function ResetUI {
    $IconList.Rows.Clear()
    $ExportFormat.SelectedIndex = 0
    $ImgX.Enabled = $false
    $ImgY.Enabled = $false
    $Script:ImgRatio = $null
    $Script:Source = $null
    $ImgX.Text = $null
    $ImgY.Text = $null
    $ExpPathGrp.Enabled = $false
    $B64RadioBtn.Checked = $true
    $InputFile.Text = $null
}
#
#
# Form events
$BrowseBtn.Add_Click({
    ResetUI
    $null = $FileBrowser.ShowDialog()
    If ($FileBrowser.FileName) {
        Try {
            $InputFileType =  (Split-Path -Path $FileBrowser.FileName -Leaf -ErrorAction Stop).Split(".")[1]
        }
        Catch {
            $LoggingText.AppendText("`r`nError determining file type`r`n" + "$_")
        }
        If ($InputFileType -in ('exe','dll','ico','icon')) {
    # Icon source, extract icons to list
            $LoggingText.AppendText("`r`nIcon source")
            $Script:Source = 'Icon'
            $SelectedFile = $InputFile.Text = $FileBrowser.FileName
            $index = 0
            $LoggingText.AppendText("`r`nExtracting icons from $SelectedFile")
            Do {
                Try { 
                    $icon = [System.IconExtractor]::Extract($SelectedFile, $index, $true)
                } 
                Catch {
                    $LoggingText.AppendText("`r`nCould not extract icon.`r`n" + "$_")
                }
                Try {
                    If ($icon) {
                        $IcoImage = $icon.ToBitmap()
                        $IconList.Rows.Add($index,$IcoImage)
                        $icon.Dispose()	
                    }
                }
                Catch {
                    $LoggingText.AppendText("`r`nError`r`n" + "$_")
                }
                $index++
            } While ($icon -ne $null)
            If ($index = 0) {
                $LoggingText.AppendText("`r`nNo icons to extract")
            }
            Else {
                $ExpPathGrp.Enabled = $true
            }
        }
        ElseIf ($InputFileType -in $ValidFileTypes) {
    # Image Source
            $ImageObj = $Canvas = $Graphic = $null
            $PreviewSize = 64
            $LoggingText.AppendText("`r`nImage source")
            $Script:Source = 'Image'
            $SelectedFile = $InputFile.Text = $FileBrowser.FileName
            Try {
                $ImageObj = [System.Drawing.Image]::FromFile((Get-Item $SelectedFile -ErrorAction Stop))
                [int]$DefImgX = $ImgX.Text = $ImageObj.Width
                [int]$DefImgY = $ImgY.Text = $ImageObj.Height
                $Script:ImgRatio = $DefImgX / $DefImgY
                # $LoggingText.AppendText("`r`nPreviewSize = $PreviewSize`r`nRatio = $ImgRatio")
        # Create preview image
                If ($ImgRatio -eq 1) {
                    [int]$NewHeight = [int]$NewWidth = $PreviewSize
                }
                ElseIf ($ImgRatio -gt 1) {
                    [int]$NewHeight = $PreviewSize / $ImgRatio
                    [int]$NewWidth = $PreviewSize
                }
                Else {
                    [int]$NewHeight = $PreviewSize
                    [int]$NewWidth = $PreviewSize * $ImgRatio
                }
                # $LoggingText.AppendText("`r`nNewHeight = $NewHeight`r`nNewWidth = $NewWidth")
                $Canvas = New-Object System.Drawing.Bitmap($NewWidth,$NewHeight) -ErrorAction Stop
                $Graphic = [System.Drawing.Graphics]::FromImage($Canvas)
                $Graphic.DrawImage($ImageObj, 0, 0,$NewWidth,$NewHeight)
                $IconList.Rows.Add('-',$Canvas)
                $ExpPathGrp.Enabled = $true
            }
            Catch {
                $LoggingText.AppendText("`r`nError: " + "$_")
            }
        }
        Else {
            $LoggingText.AppendText("`r`nInvalid file type")
            Return
        }
    }
    Else {
        $LoggingText.AppendText("`r`nNo file selected")
    }
    $LoggingText.AppendText("`r`nDone")
    If (Test-Path -Path $ExportText.Text) {
        $ExportGrpBox.Enabled = $true
    }
    Else {
        $LoggingText.AppendText("`r`nPlease choose valid output path for exported data/file")
    }
})
#
$ExportPathBtn.Add_Click({
    $ExportGrpBox.Enabled = $false
    $ExportPath = Select-Folder "$env:USERPROFILE\Downloads" 
    If ($ExportPath -ne 'Invalid Path') {
        $ExportText.Text = $ExportPath
        $ExportGrpBox.Enabled = $true
        $LoggingText.AppendText("`r`nExport path will be $ExportPath")
    }
    Else {
        $LoggingText.AppendText("`r`nNo valid folder path selected")
    }
})
#
#
$B64RadioBtn.Add_CheckedChanged({
    If ($B64RadioBtn.Checked) {
        $B64ExportType.Enabled = $B64Format.Enabled = $ExportBtn.Enabled = $FormatLines.Enabled = $true
        $ExportFormat.Enabled = $ImgSize.Enabled = $ImgX.Enabled = $false
    }
    Else {
        $B64ExportType.Enabled = $B64Format.Enabled = $FormatLines.Enabled = $false
        $ExportBtn.Enabled = $ExportFormat.Enabled = $true
        If ($Script:Source -eq 'Icon') {
            $ImgX.Enabled = $ImgY.Enabled = $false
            $ImgSize.Enabled = $true
        }
        Else {
            $ImgX.Enabled = $ImgY.Enabled = $ImgSize.Enabled = $true
        }
        If ($ExportFormat.Text -eq 'ico') {
            $ImgX.Enabled = $ImgY.Enabled = $false
        }
        Else {
            $ImgX.Enabled = $ImgY.Enabled = $true
        }
    }
})
#
#
$B64Format.Add_CheckedChanged({
    If($B64Format.Checked) {
        $FormatLines.Enabled = $true
    }
    Else {
        $FormatLines.Enabled = $false
    }
})
#
#
$ExportFormat.Add_SelectedIndexChanged({
    If ($Script:Source -ne 'Icon') {
        If ($ExportFormat.Text -eq 'ico') {
            $ImgX.Enabled = $ImgY.Enabled = $false
            $ImgSize.Enabled = $true
        }
        Else {
            $ImgX.Enabled = $ImgY.Enabled = $true
            $ImgSize.Enabled = $false
        }
    }
})
#
#
$ImgX.Add_TextChanged({
    If ($ImgX.Enabled) {
        $ImgY.Enabled = $false
        $ImgY.Text = [int]($ImgX.Text / $Script:ImgRatio)
        $ImgY.Enabled = $true
        $ImgX.Focus()
        $ImgX.Select($ImgX.Text.Length, 0)
    }
})
#
#
$ImgY.Add_TextChanged({
    If ($ImgY.Enabled) {
        $ImgX.Enabled = $false
        $ImgX.Text = [int]($ImgY.Text * $Script:ImgRatio)
        $ImgX.Enabled = $true
        $ImgY.Focus()
        $ImgY.Select($ImgY.Text.Length, 0)
    }
})
#
#
$ExportBtn.Add_Click({
    If ($IconList.SelectedRows) {
        $CurIndex = $Iconlist.SelectedRows[0].Index
        # Construct output filename
        $OutfileName = Join-Path -Path $ExportText.Text -ChildPath ((Split-Path -Path $InputFile.Text -Leaf) + "_" + $CurIndex)
        $LoggingText.AppendText("`r`nItem index $CurIndex is selected for processing")
    ###
    # Export to Base64
    ###
        If ($B64RadioBtn.Checked) {
            Try {
                $LoggingText.AppendText("`r`nConverting to Base64")
                Switch ($Script:Source) {
                    'Icon' {
                        $LoggingText.AppendText("`r`nIcon source detected")
                        $LoggingText.AppendText("`r`nProcessing data...")
                        $icon = [System.IconExtractor]::Extract($InputFile.Text, $CurIndex, $true)
                        $MemoryStream = New-Object System.IO.MemoryStream -ErrorAction Stop
                        $Icon.save($MemoryStream)
                        $Bytes = $MemoryStream.ToArray()   
                        $MemoryStream.Flush() 
                        $MemoryStream.Dispose()
                        $Base64Out = [convert]::ToBase64String($Bytes)
                    }
                    'Image' {
                        $LoggingText.AppendText("`r`nImage source detected")
                        $LoggingText.AppendText("`r`nProcessing data...")
                        $Base64Out = [convert]::ToBase64String((Get-Content -Path $InputFile.Text -Encoding Byte))
                    }
                }
                If ($B64Format.Checked) {
            # Split B64 data into lines for readability
                    $LoggingText.AppendText("`r`nFormatting data - this can take a while...")
                    $Split = While ($Base64Out) { 
                        $x,$Base64Out = ([char[]]$Base64Out).where({$_},'Split',[int]$FormatLines.Text)
                        $x -join ''
                    }
                }
                Else {
                    $Split = $Base64Out
                }
                $SavePath = "$OutfileName-Base64.txt"
                $LoggingText.AppendText("`r`n`r`nWriting data to $SavePath")
                If ($B64ExportType.Checked) {
                    $Split = $Split + "`r`n" + $CodeText
                }
                $Split | Out-File -FilePath $SavePath
                $LoggingText.AppendText("`r`nDone`r`n")
            }
            Catch {
                $LoggingText.AppendText("`r`nError`r`n" + "$_")

            }
        }
    ###
    # Export to file
    ###
        If ($ExportRadioBtn.Checked) {
            $bmp = $null
            $LoggingText.AppendText("`r`nExporting $Source to file...")
            Switch ($Script:Source) {
                'Icon' {
                    $LoggingText.AppendText("as " + $ExportFormat.Text + "`r`n")
                    Try { 
                        $icon = [System.IconExtractor]::Extract($InputFile.Text, $CurIndex, $true)
                        $bmp = $icon.ToBitmap()
                # Export icon to icon
                        If ($ExportFormat.Text -eq 'ico') {
                            $tempfile = "$OutfileName.tmp"
                            $bmp.Save($tempfile,"png")
                            $SavePath = "$OutfileName.ico"
                            $LoggingText.AppendText("`r`nWriting icon to $SavePath")
                            [PngIconConverter]::Convert($tempfile,$SavePath,$ImgSize.Text,$true) | Out-Null
                            # Keep remove-item from complaining about weird directories
                            cmd /c del $tempfile
                            $LoggingText.AppendText("`r`nDone`r`n")
                        }
                # Export icon to image
                        Else {
                            If ($ExportFormat.Text -ne 'jpg') {
                                $type = $ExportFormat.Text
                            }
                            Else {
                                $type = 'jpeg'                        
                            }
                            $SavePath = "$OutfileName." + $ExportFormat.Text
                            If ($bmp.Width -ne $ImgSize.Text) {
                                $LoggingText.AppendText("`r`nBitmap size is " + $bmp.Width + " - resizing image")
				    		# Needs to be resized
                                [int]$NewWidth = [int]$NewHeight = $ImgSize.Text
                                $NewBitmap = New-Object System.Drawing.Bitmap($NewWidth,$NewHeight) -ErrorAction Stop
                                $Graphic = [System.Drawing.Graphics]::FromImage($NewBitmap)
                            # Make it transparent - need if its not icon?
                                $LoggingText.AppendText("`r`nAdding transparency")
	    	    			    $Graphic.Clear([System.Drawing.Color]::Transparent)
                                $Graphic.DrawImage($bmp,0,0,$NewWidth,$NewHeight)
                            # Save to file
                                $LoggingText.AppendText("`r`nWriting icon data to $SavePath")
	    				    	$NewBitmap.Save($SavePath,$type)
                                $NewBitmap.Dispose()
                                $LoggingText.AppendText("`r`nDone`r`n")
                            }
                            Else {
                                $LoggingText.AppendText("`r`nWriting data to $SavePath")
                                $bmp.Save($SavePath,$type)
                                $LoggingText.AppendText("`r`nDone`r`n")
                            }
                            $bmp.Dispose()
                        }
                    $icon.Dispose()
                    }
                    Catch {
                        $LoggingText.AppendText("`r`nError resizing/saving as icon" + "$_")
                    }
                }
                'Image' {
                    $LoggingText.AppendText("as " + $ExportFormat.Text + "`r`n")
                    Try {
                        $SavePath = "$OutfileName." + $ExportFormat.Text
                        $ImageObj = $NewBitmap = $Graphic = $null
                        $SelectedFile = $InputFile.Text
                        If ($ExportFormat.Text -ne 'jpg') {
                            $type = $ExportFormat.Text
                        }
                        Else {
                            $type = 'jpeg'                        
                        }
                        #
                        ## Get image
                        $ImageObj = [System.Drawing.Image]::FromFile((Get-Item $SelectedFile -ErrorAction Stop))
                    ## Save as icon
                        If ($type -eq 'ico') {
                        # Resize image
                            $LoggingText.AppendText("`r`nResizing for icon image...")
                            [int]$NewHeight = [int]$NewWidth = $ImgSize.Text
                            $NewBitmap = New-Object System.Drawing.Bitmap($NewWidth,$NewHeight)
                            $Graphic = [System.Drawing.Graphics]::FromImage($NewBitmap)
                        # Is image square?
                            If ($Script:ImgRatio -eq 1) {
                                $LocationX = 0
                                $LocationY = 0
                            }
                        # Image not square - place into square canvas so that image isn't "squashed"
                            ElseIf ($Script:ImgRatio -gt 1) {
                                $LoggingText.AppendText("`r`nWide image, centering on square canvas")
                                $LoggingText.AppendText("`r`nImage ratio: $ImgRatio")
                                [int]$NewWidth = $ImgSize.Text
                                [int]$NewHeight = [int]$ImgSize.Text / $ImgRatio
                                $LoggingText.AppendText("`r`nSize (x,y): $NewWidth,$NewHeight")
                                [int]$LocationX = 0
                                [int]$LocationY = ([int]$NewBitmap.Height - [int]$NewHeight)/2
                                $LoggingText.AppendText("`r`nLocation (x,y): $LocationX,$LocationY")
                            }
                            Else {
                                $LoggingText.AppendText("`r`nTall image, centering on square canvas")
                                $LoggingText.AppendText("`r`nImage ratio: $ImgRatio")
                                [int]$NewWidth = [int]$ImgSize.Text * $ImgRatio
                                [int]$NewHeight = $ImgSize.Text
                                $LoggingText.AppendText("`r`nSize (x,y): $NewWidth,$NewHeight")
                                [int]$LocationX = ([int]$NewBitmap.Width - [int]$NewWidth)/2
                                [int]$LocationY = 0
                                $LoggingText.AppendText("`r`nLocation (x,y): $LocationX,$LocationY")
                            }
                            # Add transparency
                            $Graphic.Clear([System.Drawing.Color]::Transparent)
                            # Write image into location on square bitmap
                            $Graphic.DrawImage($ImageObj,$LocationX,$LocationY,$NewWidth,$NewHeight)
                            # Save to PNG temp file
                            $tempfile = "$OutfileName.tmp"
                            $NewBitmap.Save($tempfile,"png")
                            $SavePath = "$OutfileName.ico"
                            $LoggingText.AppendText("`r`nWriting icon data to $SavePath")
                            [PngIconConverter]::Convert($tempfile,$SavePath,$ImgSize.Text,$true) | Out-Null
                            # Keep remove-item from complaining about weird directories
                            cmd /c del $tempfile
                            $NewBitmap.Dispose()
                            #
                        }
                        Else {
                    # Not saving to icon, save to image file
                            # Create canvas with correct size
                            $LoggingText.AppendText("`r`nConverting image to $type")
                            [int]$NewHeight = $ImgY.Text
                            [int]$NewWidth = $ImgX.Text
                            $NewBitmap = New-Object System.Drawing.Bitmap($NewWidth,$NewHeight)
                            $Graphic = [System.Drawing.Graphics]::FromImage($NewBitmap)
                            $Graphic.DrawImage($ImageObj,0,0,$NewWidth,$NewHeight)
                            $LoggingText.AppendText("`r`nSaving image as $type")
                            $SavePath = "$OutfileName." + $type
                            $NewBitmap.Save($SavePath,$type)
                        }
                    }
                    Catch {
                        $LoggingText.AppendText("`r`nError resizing/saving as image" + "$_")
                    }
                }
            }
            $LoggingText.AppendText("`r`nDone`r`n")
        }
    ResetUI
    }
    Else {
        $LoggingText.AppendText("`r`nNo item selected for processing")
    }
})
#
# Show form
$form.ShowDialog() | Out-Null
$form.Dispose()
# End
#Region B64CodeSample
#
$CodeText = @'
#
#
# Paste Base64 data string(s) into these variables as required
#
# Embedded image
$EmbedImage = ''
#
# Form Icon
$AppIcon = ''
#
# Now we convert Base64 data back to objects
#
Function Get-ImgStreamFromB64 ($B64Img) {
    $Bytes = [Convert]::FromBase64String($B64Img)
    $stream = New-Object IO.MemoryStream($Bytes, 0, $Bytes.Length)
    $stream.Write($Bytes, 0, $Bytes.Length);
    Return $stream
}
#
$MyImg = New-Object System.Drawing.Bitmap -Argument (Get-ImgStreamFromB64 $EmbedImage)
$MyIcon = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument (Get-ImgStreamFromB64 $AppIcon)).GetHIcon())
#
#
# Now use Image/Icon in form e.g.
$form = New-Object System.Windows.Forms.Form
$form.size = '500,500'
$form.Icon = $MyIcon

$EmbedImage = New-Object System.Windows.Forms.PictureBox
$EmbedImage.Width = $MyImg.Width
$EmbedImage.Height = $MyImg.Height
$EmbedImage.Location = New-Object System.Drawing.Point(($form.Width - $MyImg.Width - 30), (10))
$EmbedImage.Image = $MyImg
$EmbedImage.Anchor = 'Top,Right'

$form.Controls.Add($EmbedImage)

#
# Show form
$form.ShowDialog() | Out-Null
$form.Dispose()
#
'@ -replace "`n", ""
#EndRegion B64CodeSample
