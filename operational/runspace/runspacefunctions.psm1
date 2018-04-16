Function Set-Indicators{
            Param(
                $customizationFile,
                $syncHash,
                $statusIndicator,
                $status,
                $message = ''
            )

            $syncHash.Host = $host
            $Runspace = [runspacefactory]::CreateRunspace()
            $Runspace.ApartmentState = "STA"
            $Runspace.ThreadOptions = "ReuseThread"
            $Runspace.Open()
            $Runspace.SessionStateProxy.SetVariable("customizationFile",$customizationFile)
            $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
            $Runspace.SessionStateProxy.SetVariable("statusIndicator",$statusIndicator)
            $Runspace.SessionStateProxy.SetVariable("status",$status)
            $Runspace.SessionStateProxy.SetVariable("message",$message)

            $code = {
                switch($status){
                    'Success'   {$image = "file://$((-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\images\success.gif')))"}
                    'Working'   {$image = "file://$((-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\images\working.gif')))"; $message = 'Working...';}
                    'Warning'   {$image = "file://$((-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\images\warning.gif')))";}
                    'Error'     {$image = "file://$((-join($customizationFile.workspace.applicationInfo.applicationRoot,'\operational\images\error.gif')))";}
                }

                $syncHash.Window.Dispatcher.invoke(
                    [action]{
                        $syncHash.Window.FindName($statusIndicator).Source = $image
                        $syncHash.Window.FindName($statusIndicator).ToolTip = $message
                    }
                )
            }
            $PSinstance = [powershell]::Create().AddScript($Code)
            $PSinstance.Runspace = $Runspace
            $job = $PSinstance.BeginInvoke()
        }

        Function Set-Textbox{
            Param(
                $customizationFile,
                $syncHash,
                $textbox,
                $message = ''
            )

            $syncHash.Host = $host
            $Runspace = [runspacefactory]::CreateRunspace()
            $Runspace.ApartmentState = "STA"
            $Runspace.ThreadOptions = "ReuseThread"
            $Runspace.Open()
            $Runspace.SessionStateProxy.SetVariable("customizationFile",$customizationFile)
            $Runspace.SessionStateProxy.SetVariable("syncHash",$syncHash)
            $Runspace.SessionStateProxy.SetVariable("textbox",$textbox)
            $Runspace.SessionStateProxy.SetVariable("message",$message)

            $code = {
                Start-Sleep -seconds 5
                $syncHash.Window.Dispatcher.invoke(
                    [action]{
                        $syncHash.Window.FindName($textbox).Text = $message
                    }
                )
            }
            $PSinstance = [powershell]::Create().AddScript($Code)
            $PSinstance.Runspace = $Runspace
            $job = $PSinstance.BeginInvoke()
        }