$mapGUIDirectory = (-join($env:APPDATA,'\mapGUI\'))
if(Test-Path $mapGUIDirectory){
    if(Get-ChildItem $mapGUIDirectory){
        $backupDirectory = New-Item -ItemType Directory (-join($mapGUIDirectory,'\backup\',(Get-Date -Format 'yyyyMMddHHmmss')))
        Get-ChildItem $mapGUIDirectory | Where-Object { $_.FullName -notmatch 'backup' } | Copy-Item -Recurse -Destination $backupDirectory
        Get-ChildItem $mapGUIDirectory | Where-Object { $_.FullName -notmatch 'backup' } | Remove-Item -Force -Recurse -Confirm:$false
        $backup = $true
    }
}
else{
    $mapGUIDirectory = New-Item (-join($env:APPDATA,'\mapGUI\')) -ItemType Directory
}

[Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
$latestRelease = (Invoke-WebRequest -uri 'https://github.com/mpearon/mapGUI/releases/latest').links | Where-Object { $_.outerText -match '(zip)' }
#Invoke-WebRequest -Uri 'https://github.com/mpearon/mapGUI/archive/master.zip' -OutFile (-join($mapGUIDirectory,'\mapGUI-Source.zip'))
Invoke-WebRequest -Uri (-join('https://github.com',$latestRelease)) -OutFile (-join($mapGUIDirectory,'\mapGUI-Source.zip'))
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory((-join($mapGUIDirectory,'\mapGUI-Source.zip')), $mapGUIDirectory)
Remove-Item (-join($mapGUIDirectory,'\mapGUI-Source.zip')) -Force -Recurse -Confirm:$false
if($backup){
    Get-ChildItem (-join($mapGUIDirectory,'\mapGUI-master')) | Where-Object { $_.FullName -notmatch 'backup' } | ForEach-Object{
        Move-Item $_.FullName -Destination $mapGUIDirectory
    }
    Copy-Item (-join($backupDirectory,'\customizations')) -Recurse -Destination $mapGUIDirectory -Force
}
else{
    Get-ChildItem (-join($mapGUIDirectory,'\mapGUI-master')) | ForEach-Object{
        Move-Item $_.FullName -Destination $mapGUIDirectory -Force
    }
}
Remove-Item (-join($mapGUIDirectory,'\mapGUI-master')) -Force -Recurse -Confirm:$false

Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/mpearon/PowerShell/master/Personal/StoryUp/StoryUpGUI/customizations/modules/storyUp.psm1' -OutFile (-join($mapGUIDirectory,'\customizations\modules\storyUp.psm1'))

$customizationFile = Get-Item (-join($env:APPDATA,'\mapGUI\customizations\defaults.json'))
$customizationFileContents = Get-Content $customizationFile | ConvertFrom-Json
$customizationFileContents.workspace.applicationinfo.applicationRoot = ($customizationFile.Directory.Parent).FullName
(-join('[',($customizationFileContents | ConvertTo-Json),']')) | Out-File $customizationFile

$AppLocation = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$arguments = (-join($env:APPDATA,'\mapGUI\mapGUI.ps1'))
$WshShell = New-Object -ComObject WScript.Shell
#create appData shortcut
$Shortcut = $WshShell.CreateShortcut(-join($env:APPDATA,'\mapGUI\mapGUI.lnk'))
$Shortcut.TargetPath = $AppLocation
$Shortcut.Arguments = "-windowStyle Hidden -noExit $Arguments"
$Shortcut.Save()
#create desktop shortcut
$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\mapGUI.lnk")
$Shortcut.TargetPath = $AppLocation
$Shortcut.Arguments = "-windowStyle Hidden -noExit $Arguments"
$Shortcut.Save()

Invoke-Item (-join($Home,'\Desktop\mapGUI.lnk'))
