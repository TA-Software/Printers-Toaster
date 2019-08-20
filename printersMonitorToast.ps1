Function getTrayStatus {
    Param(
        $code
    )
    
    $statusList = 'Ready','Empty','Unknown','Not Available'

    return $statusList[$code]
}

Function getCartridgeStatus {
    Param(
        $code
    )
    
    $statusList = 'OK','Cartridge Mismatch','Replace Soon','Replace Now','Setup in progress...','Missing or Not Fully Inserted.','Fault','OK (Reorder)','Attention Required'

    return $statusList[$code]
}

Function getTonerStatus {
    Param(
        $code
    )
    
    $statusList = 'OK','Reorder','Replace Now','Sensor Failure','Not Installed','OK (Reorder)'

    return $statusList[$code]
}


$content = Invoke-WebRequest -Uri 10.61.50.108:8888/printerstatus/all | ConvertFrom-Json
$URL = "http://10.10.121.193/Printers.aspx"
$printerWithIssue = @()

$content.result | % {
    $printerName = $_.name
    $printerIP = $_.ip
    $notification = @()

    Write-Output "================================================================="
    Write-Output "Printer Name: $printerName"
    Write-Output "Printer IP: $printerIP"

    if ($_.data.tray.error -eq 0) {

            Write-Output "`nPAPER TRAYS"
            Write-Output "-----------------------------------------"


        # Trays
        $_.data.tray.data | % {
            $trayName = $_[0]
            $trayStatusCode = $_[1]
            $trayStatus = getTrayStatus -code $trayStatusCode
            $trayPercent = $_[2]

            Write-Output "$trayName`: $trayStatus"

            If ($trayStatusCode -ne 0 -and $trayStatusCode -ne 3) {
                $notification += "$trayName - $trayStatus ($trayPercent%)"
            }
        }
    }

    if ($_.data.consumable.error -eq 0) {
        
        # Consumables
        $_.data.consumable.data | % {
            $consCategory = $_[0]
            $consData = $_[1]

            Write-Output "`n$($consCategory.ToUpper())"
            Write-Output "-----------------------------------------"
        
            switch($consCategory) {
                { $_ -in "toner cartridge(s)", "drum cartridge(s)"} {
                    $consData | % {
                        $crtName = $_[0]
                        $crtStatusCode = $_[1]
                        $crtStatus = getCartridgeStatus -code $crtStatusCode
                        $crtPercent = $_[2]
                        
                        Write-Output "$crtName`: $crtStatus"

                        If ($crtStatusCode -ne 0 -and $crtStatusCode -ne 2 -and $crtStatusCode -ne 4 -and $crtStatusCode -ne 7) {
                            $notification += "$crtName - $crtStatus ($crtPercent%)"
                        }
                    }
                }

                "waste toner container" {
                    $tonerStatusCode = $consData
                    $tonerStatus = getTonerStatus -code $tonerStatusCode

                    Write-Output $tonerStatus

                    If ($tonerStatusCode -eq 0 -and $tonerStatusCode -eq 1 -and $tonerStatusCode -eq 5) {
                        $notification += "Waste Toner Container - $tonerStatus"
                    }
                }
            }
        }
    }

    Write-Output "=================================================================`n`n`n"

    If ($notification -ne @()) {

        $printerWithIssue += $printerName

        <#
        $count = $notification.Split(",").Count
        
        $title = New-BTText -Content $printerName
        $body1 = New-BTText -Content $notification[0]

        If ($count -le 2) {
            $body2 = New-BTText -Content $notification[1]
        } else {
            $body2 = New-BTText -Content ($notification[1] + "`n...and $($count-2) other(s)")
        }

        $binding = New-BTBinding -Children $title,$body1,$body2
        $visual = New-BTVisual -BindingGeneric $binding
        $content = New-BTContent -Visual $visual -Launch $URL -ActivationType Protocol
        Submit-BTNotification $content
        #>
    }
}

$title = New-BTText -Content "Printers with an issue"
$bodyString = ""

$count = $printerWithIssue.Count

If ($count -le 4) {
    For ($i=0; $i -lt $count; $i++) {
        $bodyString += "$($printerWithIssue[$i])`n"
    }
    $bodyString = $bodyString.Trim()
} Else {
    For ($i=0; $i -lt 3; $i++) {
        $bodyString += "$($printerWithIssue[$i])`n"

    }
    $bodyString += "...and $($count-3) other printer/s"
}

$body = New-BTText -Content ($bodyString)

$binding = New-BTBinding -Children $title,$body
$visual = New-BTVisual -BindingGeneric $binding
$content = New-BTContent -Visual $visual -Launch $URL -ActivationType Protocol
Submit-BTNotification $content