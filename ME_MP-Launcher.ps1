function main {

    write-host "Downloads the Mirrors Edge Multiplayer Launcher and starts the game..."

    # Get the path to the game from registry
    # HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\EA Games\Mirror's Edge
    $ME_RegistryPath = "HKLM:\SOFTWARE\WOW6432Node\EA Games\Mirror's Edge"
    $gamePath = Get-ItemProperty -Path $ME_RegistryPath -Name "Install Dir" | Select-Object -ExpandProperty "Install Dir"
    $launcherUrl = "https://api.github.com/repos/btbd/mmultiplayer/releases/latest"
    $launcherPath = "$gamePath" + "MMultiplayer_Launcher.exe"
    $GameExe = "$gamePath" + "Binaries\MirrorsEdge.exe"
    $oldlauncherPath = "$gamePath" + "MMultiplayer_Launcher.exe.old"

    # Check if an old version and a new version exists and delete the old one otherwise leave it there
    # needs admin rights to delete it.
    write-host "Checking for old Launcher"
    if ((test-path -Path $oldlauncherPath) -and (Test-Path -Path $launcherPath)) {
        if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
        {
            Read-Host "Old Launcher found, need to restart the script as admin to delete it.
            Press Enter to restart the script as admin..."
            # Relaunch the script with administrator rights
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$PSCommandPath`"", "-Url $downloadUrl", "-Path $launcherPath"
            exit
        }
        Remove-Item -Path $oldlauncherPath -Force
    }

    # Some functions    
    # Function to download the file
    function DownloadFile {
        Param (
            [string]$Url,
            [string]$Path
        )

        Invoke-WebRequest -Uri $Url -OutFile $Path
        Write-Host "File downloaded to $Path"
    }
    # Function to get the current mod version
    function get-modversion {

        $path = $ME_RegistryPath
        try {
            $modversion = Get-ItemProperty -Path $Path -Name "ModVersion" | Select-Object -ExpandProperty "ModVersion" -ErrorAction SilentlyContinue
        }
        catch {
            $modversion = 0
        }
        
        if ($modversion)
        {
            write-host "ModVersion: $modversion"
            return $modversion
        }
        else
        {
            write-host "ModVersion: 0"
            return 0
        }
            
    }
    # Function to write the current mod version
    function write-modversion {
       
        Param (
            [string]$version
        )

        $path = $ME_RegistryPath
        #$modversion  = Get-ItemProperty -Path $Path -Name "ModVersion" | Select-Object -ExpandProperty "ModVersion" -ErrorAction SilentlyContinue

        if (get-modversion)
        {
            set-ItemProperty -Path $Path -Name "ModVersion"  -Value $version -PropertyType String -Force
        }
        else
        {
            New-ItemProperty -Path $Path -Name "ModVersion" -Value $version -PropertyType String -Force
        }
        
    }

    # Get information about the latest release from github
    $response = Invoke-RestMethod -Uri $launcherUrl -Headers @{ Accept = "application/vnd.github.v3+json" }
    
    # Download the Launcher from github if it doesn't exist or is older than latest github release
    # https://api.github.com/repos/btbd/mmultiplayer/releases/latest
    # https://github.com/btbd/mmultiplayer
    if ((Test-Path $launcherPath) -and (get-modversion -ne 0) -or ((Test-Path $launcherPath) -and (get-modversion -ge $response.tag_name))) {
        Write-Host "Launcher already downloaded and on newest version"
    } else {
        write-Host "Downloading Launcher from GitHub"

        # Extract the download URL for the Launcher's exe file from the response
        $downloadUrl = $response.assets | Where-Object { $_.name -like "*MMultiplayer_Launcher.exe" } | Select-Object -ExpandProperty browser_download_url

        # Download the Launcher
        if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
        {
            # Relaunch the script with administrator rights
            Start-Process powershell.exe -Verb RunAs -ArgumentList "-File `"$PSCommandPath`"", "-Url $downloadUrl", "-Path $launcherPath"
            exit
        } else {
            # check if the mod exists on filesystem
            if (Test-Path $launcherPath) {
                # rename the old launcher
                Rename-Item -Path $launcherPath -NewName $oldlauncherPath
            }
            # Try to download the Launcher
            try {
                DownloadFile -Url $downloadUrl -Path $launcherPath
            }
            catch {
                write-host "Error downloading the Launcher"
                write-host "rollback to old Launcher"
                Rename-Item -Path $oldlauncherPath -NewName $launcherPath
                Read-Host -Prompt "Press Enter to exit"
                exit
            }
            # double check because i just don't trust windows and myselfe
            if (Test-Path $launcherPath) {
                write-host "Launcher downloaded, writing mod version to registry"
                write-modversion -version $response.tag_name
            } else {
                write-host "Error downloading the Launcher try again"
                Read-Host -Prompt "Press Enter to exit"
                exit
            }
            
        }
        
        Write-Host "Launcher downloaded to $launcherPath"
        write-host "cleaning up old version if there are any...."
        if (Test-Path $oldlauncherPath) {
            try {
                remove-item -Path $oldlauncherPath -Force
            }
            catch {
                write-host "Couldn't remove old Launcher, maybe it has a filelock. Trying to kill the exe now..."
    
                try {
                    Get-Process -Name MMultiplayer_Launcher | Stop-Process -Force
                }
                catch {
                    $reboot = Read-Host "Couldn't kill the old Launcher, maybe it is running. Do you want to restart your PC now? (y/n)"
                    if ($reboot -eq "y") {
                        Restart-Computer
                    }  else {
                        write-host "Please restart your PC manually to unlock the old launcher. It will cleanup the old file when you run this script again."
                        Read-Host -Prompt "Press Enter to exit"
                        exit
                    }
                }
            }
        }
    }

    # Start the Launcher and the game
    write-host "Starting Launcher and Game"
    Start-Process -FilePath $GameExe
    Start-Process -FilePath $launcherPath
}

main