[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
$global:customizationFile = Get-Content ( -join ($PSScriptRoot,'\customizations\defaults.json')) | ConvertFrom-JSON

$Runspace = [runspacefactory]::CreateRunspace()
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()

$masterRunspaceCode = {
    Param(
        $Global:customizationFile
    )
    if(($customizationFile.workspace.applicationInfo.applicationRoot) -eq ''){
        $customizationFile.workspace.applicationInfo.applicationRoot = $env:TEMP
    }
    $applicationRoot = $PSScriptRoot
    Import-Module (-join($customizationFile.workspace.applicationInfo.applicationRoot,'\customizations\modules\',($customizationFile.workspace.applicationInfo.modulesToImport)[0]))
    switch($customizationFile.workspace.applicationInfo.colorScheme){
        'light' { $primaryColor = 'White'; $accentColor = 'Black'; $colorIndex = 0; }
        'dark'  { $primaryColor = 'Black'; $accentColor = 'White'; $colorIndex = 1; }
        default { $primaryColor = 'White'; $accentColor = 'Black'; $colorIndex = 0; }
    }
    $rawUI = Get-Content (-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\ui\mainui.xaml'))
    [xml]$xaml = $ExecutionContext.InvokeCommand.ExpandString($rawUI)

    #Read XAML
    $syncHash = [hashtable]::Synchronized(@{})
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $syncHash.Window = [Windows.Markup.XamlReader]::Load( $reader )

    #Create Variables
    $xaml.SelectNodes("//*[@Name]") | ForEach-Object{
        Set-Variable -Name ($_.Name) -Value $syncHash.Window.FindName($_.Name) -Scope Global
    }

    #Form
    $btn_Exit.Add_Click({
        $syncHash.Window.Close()
        Stop-Process $pid
    })
    $img_logo.Add_MouseLeftButtonDown({
        $syncHash.Window.DragMove()
    })
    $img_projectcreator_createresult.Add_MouseLeftButtonDown({
        $img_projectcreator_createresult.Source = "{x:Null}"
    })
    $img_pngsequencer_sequenceresult.Add_MouseLeftButtonDown({
        $img_pngsequencer_sequenceresult.Source = "{x:Null}"
    })

    #AppLauncher Tab
    $btn_applauncher_app1.Add_Click({
        Start-Process $customizationFile.applications.app1.appPath
        [System.Console]::Beep(1200,100)
    })
    $btn_applauncher_app2.Add_Click({
        Start-Process $customizationFile.applications.app2.appPath
        [System.Console]::Beep(1200,100)
    })
    $btn_applauncher_app3.Add_Click({
        Start-Process $customizationFile.applications.app3.appPath
        [System.Console]::Beep(1200,100)
    })
    $btn_applauncher_app4.Add_Click({
        Start-Process $customizationFile.applications.app4.appPath
        [System.Console]::Beep(1200,100)
    })
    $btn_applauncher_app5.Add_Click({
        Start-Process $customizationFile.applications.app5.appPath
        [System.Console]::Beep(1200,100)
    })
    $btn_applauncher_app6.Add_Click({
        Start-Process $customizationFile.applications.app6.appPath
        [System.Console]::Beep(1200,100)
    })

    #Functions
    $runspaceFunctions = Get-Content (-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\runspace\runspacefunctions.psm1')) | Out-String
    Function Invoke-InRunspace{
        Param(
            $customizationFile,
            $logPath = (-join('C:\temp\',(Get-Date -Format yyyyMMdd),'-Operational.log')),
            $syncHash,
            $runspaceFunctions,
            $commandLine,
            $statusIndicator,
            [switch]$importModules
        )
        $syncHash.Host = $host
        $runspace = [RunspaceFactory]::CreateRunspace()
        $runspace.ApartmentState = 'STA'
        $runspace.ThreadOptions = 'ReuseThread'
        $runspace.Open()
        $runspace.SessionStateProxy.SetVariable('verbosePreference','Continue')
        $runspace.SessionStateProxy.SetVariable('customizationFile',$customizationFile)
        $runspace.SessionStateProxy.SetVariable('logPath',$logPath)
        $runspace.SessionStateProxy.SetVariable('syncHash',$syncHash)
        $runspace.SessionStateProxy.SetVariable('runspaceFunctions',$runspaceFunctions)
        $runspace.SessionStateProxy.SetVariable('commandLine',$commandLine)
        $runspace.SessionStateProxy.SetVariable('statusIndicator',$statusIndicator)
        $runspace.SessionStateProxy.SetVariable('importModules',$importModules)

        $runspaceCode = {
            Invoke-Expression $runspaceFunctions
            Set-Indicators -customizationFile $customizationFile -syncHash $syncHash -statusIndicator $statusIndicator -status 'Working'
            if($importModules -eq $true){
                $customizationFile.workspace.modulesToImport | ForEach-Object{
                    Import-Module (-join($customizationFile.workspace.applicationInfo.applicationRoot,'\customizations\modules\',$_)) -Verbose
                }
            }
            Write-Verbose $commandLine
            $scriptBlock = [scriptblock]::Create($commandLine)
            $return = Invoke-Command -ScriptBlock $scriptBlock -Verbose
            switch($return){
                {$_ -match 'SUCCESS|0'} { Set-Indicators -customizationFile $customizationFile -syncHash $syncHash -statusIndicator $statusIndicator -status 'Success' }
                {$_ -match 'WARNING'}   { Set-Indicators -customizationFile $customizationFile -syncHash $syncHash -statusIndicator $statusIndicator  -status 'Warning' -message $return }
                {$_ -match 'FAILURE'}   { Set-Indicators -customizationFile $customizationFile -syncHash $syncHash -statusIndicator $statusIndicator  -status 'Error' -message $return }
                default                 { Set-Indicators -customizationFile $customizationFile -syncHash $syncHash -statusIndicator $statusIndicator  -status 'Warning' -message (-join('Unknown Error: ',($Error)[0])) }
            }
        }
        $job = [powershell]::Create().AddScript($runspaceCode)
        $job.Runspace = $runspace
        $thisJob = New-Object -TypeName PSCustomObject -Property @{
            Pipe   = $job
            Result = $job.BeginInvoke()
        }
    }
    $btn_projectcreator_create.Add_Click({
            $projectName = $tbx_projectcreator_projectname.text
            $illegal =[Regex]::Escape(-join [System.Io.Path]::GetInvalidFileNameChars())
            $pattern = "[$illegal]"
            $invalid = [regex]::Matches($projectName, $pattern, 'IgnoreCase').Value | Sort-Object -Unique

            if($projectName -eq ' ' -or $projectName -eq '' -or $projectName -eq $null){
                $codeBlock = 'return "[!] FAILURE: Enter one or more comma-separated Project Names"'
                Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_projectcreator_createresult'
            }
            elseif($invalid -ne $null){
                $codeBlock = 'return "[!] FAILURE: Illegal characters detected in one or more Project Names"'
                Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_projectcreator_createresult'
            }
            else{
                Try{
                    $projectName.split(',').trim() | ForEach-Object{
                        New-ProjectDirectory -projectTitle $_ -basePath ($tbx_projectcreator_projectroot.text) -directoryArray ($tbx_projectcreator_projectdirectories.text).split(',').trim() -Force -ErrorAction Stop
                        $codeBlock = 'return "Success"'
                        Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_projectcreator_createresult'
                    }
                }
                Catch{
                    $codeBlock = 'return (-join("[!] FAILURE: Unable to create one or more directories: ",$_))'
                    Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_projectcreator_createresult'
                }
            }
        
    })
    $btn_pngsequencer_sequence.Add_Click({
        $codeBlock = "Export-AsVideo -inputPath $($tbx_pngsequencer_input.text) -workingPath $($tbx_pngsequencer_working.text) -outputPath $($tbx_pngsequencer_output.text)"
        Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_pngsequencer_sequenceresult' -importModules
    })

    $btn_configure_commit.Add_Click({
        Try{
            Get-Variable tbx_configure_* | ForEach-Object{
                $thisVar = $_.Name
                $userValue = $_.Name -split('_')
                $customizationFile.($userValue[2]).($userValue[3]).($userValue[4]) = ($_.Value.Text)
                $customizationFile.firstRun = $false
                Add-Content (-join($customizationFile.workspace.applicationInfo.applicationRoot,'/operational/logs/',(Get-Date -Format 'yyyMMddHHmmss'),'-configChange.log')) -Value "var: $($thisVar)`r`n   1: $($userValue[2])`r`n   2: $($userValue[3])`r`n   2: $($userValue[4])`r`n   Value: $($_.Value.Text)`r`n" -ErrorAction Stop
            }
            (-join('[',($customizationFile | ConvertTo-JSON -ErrorAction Stop),']')) | Out-File (-join($customizationFile.workspace.applicationInfo.applicationRoot,'/customizations/defaults.json')) -Force -ErrorAction Stop
            $lbl_alert.Foreground = '#FF970F0F'
            $lbl_alert.Content = 'Restart Application'
            $codeBlock = 'return "Success"'
            Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_configure_commitresult'
        }
        Catch{
            $codeBlock = 'return (-join("[!] FAILURE: Unable to update configuration: ",$_))'
            Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_configure_commitresult'
        }
    })
    if($customizationFile.firstRun -eq $true){
        $tc_tabs.SelectedIndex = "3"
        $lbl_alert.Content = 'First Run - Configuration'
    }

    $btn_configure_update.Add_Click({
        Start-Process PowerShell -ArgumentList "-Command `"&{ Write-Host -ForegroundColor Red 'UPDATE IN PROGRESS'; & (-join(`$env:APPDATA,'\mapGUI\install.ps1'))}`""
        $syncHash.Window.Close()
        Stop-Process $pid
    })

    #Version Checking
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
    $installedRelease = Get-Content (-join($env:APPDATA,'\mapGUI\operational\release'))
    $latestRelease = ((Invoke-WebRequest 'https://github.com/mpearon/mapGUI/releases/latest' -ErrorAction SilentlyContinue).links | Where-Object { $_.innerText -match 'v\d\.\d' -and ($_.outerText -eq $_.innerText) } | Sort-Object innerHTML | Select-Object -Last 1).innerText

    $lbl_configure_currentversion.Content = $installedRelease

    if([System.Version]($installedRelease.replace('v','')) -lt ([System.Version]$latestRelease.replace('v',''))){
        $lbl_alert.Foreground = '#FFFF00'
        $lbl_alert.Content = 'Update Available'
        $codeBlock = 'return "Warning"'
        Invoke-InRunspace -customizationFile $customizationFile -syncHash $syncHash -runspaceFunctions $runspaceFunctions -commandLine $codeBlock -statusIndicator 'img_configure_updatealert'
    }

    $syncHash.Window.ShowDialog()
    $Runspace.Close()
    $Runspace.Dispose()
}

$PSinstance1 = [powershell]::Create().AddScript($masterRunspaceCode).AddParameters($customizationFile)
$PSinstance1.Runspace = $Runspace
$job = $PSinstance1.BeginInvoke()