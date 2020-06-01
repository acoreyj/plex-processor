# _______________________________________________________________________________________ #
#                                                                                         #
#                                        VARIABLES                                        #
# _______________________________________________________________________________________ #
#                                                                                         #
# These are the variables that you need to set before the script can work.                #
# If there is variable missing or a feature you want, please log an issue github          #
#                                                                                         #
# If you are using uTorrent, make sure that it appends files with !ut whilst downloading  #
# If you are using another download client, it is best advised to download to a different #
# folder than the source set below, and have the downloader move the file once completed  #
#                                                                                         #
# _______________________________________________________________________________________ #


$sourcefolder = "\\RASPBERRYPI\pi2k\Sonarr"
$destinationfolder = "\\RASPBERRYPI\pi2k\media\TV"
$logfolder = "\\RASPBERRYPI\pi2k\media"

$lockdest = "\\RASPBERRYPI\pi2k\media" # <----- This is where the .lock files go that allow the script to see if it is already running or encoding

$newfileext = "mp4" # <------ choose mkv or mp4 
$recursive = 1 # <----------- set to 1 to enable recursive source folder scan
$remold = 0 # <-------------- set to 1 to delete source files after re-encode
$clrrcl = 0 # <-------------- set to 1 to clear recycle bin after script finishes
$sonarr = 1 # <------------ set this to 1 if you want sonarr to search for content after conversion then set the relevant fields below.

$sonarrURL = "http://raspberrypi.local:8989"
$sonarrAPI = "3b93d4d21b50429ea4bc8f1416082b54"

$changeaffinity = 0 # <------ if you want to change the affinity of handbrakeCLI set this to 1 and change the decimal values below
$decimal = 255 # <----------- decimal values available via google or here: https://stackoverflow.com/questions/19187241/change-affinity-of-process-with-windows-script
#                        \--- This will vary depending on how many cores/threads your processor has. i.e. a Ryzen 8C/16T CPU will be 65535 but an i7 4C/8T CPU will be 255 for all cores

<#

HANDBRAKE ARGUMENTS
Set the arguments below, leaving out the imput and output file options (these are set below on a dynamic basis within the script)
see handbrake cli documentation here: https://handbrake.fr/docs/en/latest/cli/cli-guide.html

#>

$handargs = "--preset-import-file \\RASPBERRYPI\pi2k\Plex1080p265.json"

<# 

IMPORT HANDBRAKE PROFILE FROM GUI
Alternatively, instead of setting the arguments manually, you can import a profile that you have already saved within the normal handbrake application
Set the below option to "1" and then set the name of the profile you want to use. Make sure the profile name has no spaces, and enter it exactly as it appears in handbrake

#>

$import = 0
$profile = "Plex1080265"

$hidden = 0 # <-------------- Set this to 1 to hide the handbrake CLI window. If you want to watch it whirring away, keep set to 0
$notifications = 0 # <------- Set this to 1 to enable Windows 10 Toast Notifications (requires Creators Update to work properly)



# _______________________________________________________________________________________ #
#                                                                                         #
#                                      SCRIPT START                                       #
# _______________________________________________________________________________________ #

if ($notifications -eq 1) {
    if ((Test-Path "C:\Program Files\WindowsPowerShell\Modules\BurntToast") -eq $false) { Install-Module Burnttoast }
}

Write-Output "bambam"
if ($sourcefolder -eq $destinationfolder) { 
    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [Windows.Forms.MessageBox]::Show("Source and destination folders cannot be the same!", "Check File Path Variables", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error)
    Exit
}

if ((Test-Path $lockdest\running.lock) -eq $false) { New-Item $lockdest\running.lock -type file } else { exit }

if ($remold -eq 1) {
    $excluded = @("*.mp4", "*.mkv", "*.avi", "*.mpeg4", "*.ts", "*.!ut", "encoding.log")
    Get-ChildItem $sourcefolder\* -Exclude $excluded -Recurse | where { ! $_.PSIsContainer } | foreach ($_) { Remove-Item -LiteralPath $_.FullName -Force }
    Get-ChildItem $sourcefolder -Filter "RARBG.mp4" -Recurse | foreach ($_) { Remove-Item -LiteralPath $_.FullName -Force }
}

$included = @("*.mp4", "*.mkv", "*.avi", "*.mpeg4", "*.ts")


$excluded = @("RARBG.mp4", "*sample*")
if ((Test-Path $logfolder\previouslycompleted.log) -eq $false) { New-Item $logfolder\previouslycompleted.log -type file }
$previous = @(get-content -path $logfolder\previouslycompleted.log)

$fullExcluded = $excluded + $previous

if ($recursive -eq 1) { 
    $filelist = Get-ChildItem $sourcefolder -Recurse -Include $included -Exclude $fullExcluded | where { ! $_.PSIsContainer } | Where { $_.FullName -notlike "*\In Progress\*" -and $_.FullName -notlike "*\Delayed\*" } 
}
else { 
    $filelist = Get-ChildItem $sourcefolder -Include $included -Exclude $fullExcluded | where { ! $_.PSIsContainer } | Where { $_.FullName -notlike "*\In Progress\*" -and $_.FullName -notlike "*\Delayed\*" }
}

$num = $filelist | measure
$filecount = $num.count 

Write-Output $filecount
if ($num.count -eq "0") { 
    remove-item -LiteralPath $lockdest\running.lock -Force
    Exit 
}

$uid = 000124
$i = 0;
$inProgressFilelist = @();
ForEach ($file in $filelist) {
    $i++;

    $randomtime = Get-Random -Minimum 1000 -Maximum 4000
    Start-Sleep -m $randomtime

    $progressfolder = $file.DirectoryName + "\" + "InProgress"
    if ((Test-Path $progressfolder) -eq $false) { New-Item $progressfolder -type directory }

    $movefile = $file.DirectoryName + "\" + $file.BaseName + $file.Extension;
    $inProgressFilelist += ,$progressfolder + $movefile;
    if ($remold -eq 1) { Move-Item -literalpath $movefile -Destination $progressfolder }
    else { Copy-Item -literalpath $movefile -Destination $progressfolder }
}
Write-Output "inProgressFilelist"
Write-Output $inProgressFilelist
Get-ChildItem $sourcefolder -Recurse | Where-Object -FilterScript { $_.PSIsContainer -eq $True } | Where-Object -FilterScript { ($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0 } | foreach ($_) { remove-item -LiteralPath $_.fullname }

$filelist = Get-ChildItem -LiteralPath $inProgressFilelist -Filter *.* -Recurse | where { ! $_.PSIsContainer }
Write-Output $filelist
$num = $filelist | measure
$filecount = $num.count

$i = 0;
Write-Output $filecount
Write-Output $filelist

ForEach ($file in $filelist) {
    $i++;

    do {
        $randomtime = Get-Random -Minimum 10 -Maximum 2000
        Start-Sleep -m $randomtime 
    } 
    until ((Test-Path $lockdest\encoding.lock) -eq $false)

    New-Item $lockdest\encoding.lock -type file

    $oldfile = $file.DirectoryName + "\" + $file.BaseName + $file.Extension;
    $newfileFolder = $destinationfolder + $file.DirectoryName.replace($sourcefolder,'').replace('\InProgress','');
    if ((Test-Path $newfileFolder) -eq $false) { New-Item -path $newfileFolder -type directory }

    $newfile = $newfileFolder + "\" + $file.BaseName + ".$newfileext";
    $oldfilebase = $file.BaseName + $file.Extension;
    $date = Get-Date    
    $output1 = "-------------------------------------------------------------------------------"
    $output2 = "Handbrake Automated Encoding `r`n"
    $output3 = "$date `| Processing:    `| $oldfilebase"
    $output1 | Out-File -Append $logfolder\encoded.log
    $output2 | Out-File -Append $logfolder\encoded.log
    $output3 | Out-File -Append $logfolder\encoded.log
    Write-Output $handargs
    Write-Output $oldfile
    Write-Output $newfile

    if ($hidden -eq "1") {
        if ($import -eq 0) { Start-Process "C:\Program Files\HandBrake\HandBrakeCLI.exe" -WindowStyle Hidden -ArgumentList "$handargs -i `"$oldfile`" -o `"$newfile`"" }
        else { Start-Process "C:\Program Files\HandBrake\HandBrakeCLI.exe" -WindowStyle Hidden -ArgumentList "--preset-import-gui --preset $profile -i `"$oldfile`" -o `"$newfile`"" }
    }
    else {
        if ($import -eq 0) { Start-Process "C:\Program Files\HandBrake\HandBrakeCLI.exe" -ArgumentList "$handargs -i `"$oldfile`" -o `"$newfile`"" }
        else { Start-Process "C:\Program Files\HandBrake\HandBrakeCLI.exe" -ArgumentList "--preset-import-gui --preset $profile -i `"$oldfile`" -o `"$newfile`"" }
    }
    
    Start-Sleep -s 1

    if ($notifications -eq 1) {
        $count = "$i" + "/" + "$filecount"
        $dec = $i / ($filecount + 1)
        $perc = "{0:p0}" -f $dec
        $bar = New-BTProgressBar -Status "Encoding episode $count" -Indeterminate -ValueDisplay $perc
        if ($filecount -eq 1) { New-BurntToastNotification -Header $noth1 -Text "Found $filecount New Thing", "I’m processing it now" -ProgressBar $bar -UniqueIdentifier "$uid" -AppLogo P:\Downloads\Shows\Scripts\icon2.png }
        else { New-BurntToastNotification -Header $noth1 -Text "Found $filecount New Things", "I’m processing them now" -ProgressBar $bar -UniqueIdentifier "$uid" -AppLogo P:\Downloads\Shows\Scripts\icon2.png }
    }

    if ($changeaffinity -eq 1) {
        $affinity = Get-Process HandBrakeCLI
        $affinity.ProcessorAffinity = $decimal 
    }
    
    do { Start-Sleep -s 1 } until ((get-process HandBrakeCLI -ea SilentlyContinue) -eq $Null)
    
    $date = Get-Date
    $output5 = "$date `| Finished:      `| $newfile"
    $output5 | Out-File -Append $logfolder\encoded.log
    
    Remove-Item -LiteralPath "$oldfile" -force
    $output6 = "                    `| Deleted File:  `| $oldfile `r`n"
    $output6 | Out-File -Append $logfolder\encoded.log

    $oldfilebase | Out-File -Append $logfolder\previouslycompleted.log
    
    remove-item -LiteralPath $lockdest\encoding.lock -Force
}

if ($sonarr -eq 1) {

    $filelist2 = Get-ChildItem $destinationfolder -Filter *.* -Recurse | where { ! $_.PSIsContainer }
    ForEach ($file in $filelist2) {
        $url = "$sonarrURL/api/command"
        $json1 = "{ ""name"": ""downloadedepisodesscan"",""path"": """
        $json2 = """}"
        $encoded = $file.DirectoryName + "\" + $file.BaseName + $file.Extension;
        $escaped = $encoded.replace('\', '\\')
        $jsoncomplete = $json1 + $escaped + $json2
        Invoke-RestMethod -Uri $url -Method Post -Body $jsoncomplete -Headers @{"X-Api-Key" = "$sonarrAPI" }
    }
}

remove-item -LiteralPath $lockdest\running.lock -Force
Get-ChildItem $sourcefolder -Recurse | Where-Object -FilterScript { $_.PSIsContainer -eq $True } | Where-Object -FilterScript { ($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0 } | foreach ($_) { remove-item $_.fullname }
Get-ChildItem $sourcefolder -Recurse | Where-Object -FilterScript { $_.PSIsContainer -eq $True } | Where-Object -FilterScript { ($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0 } | foreach ($_) { remove-item $_.fullname }

if ($notifications -eq 1) { New-BurntToastNotification -Header $noth2 -text "Finished Processing $filecount Files" -UniqueIdentifier "$uid" }

if ($clrrcl -eq 1) { Clear-RecycleBin -Confirm:$False }