function Get-Usage() {
    Write-Output "Usage - CDInterface sourcePath [commands|options]"
    Write-Output "Examples"
    Write-Output "Write the contents of a directory to current media"
    Write-Output ""
    Write-Output "CDInterface -writetomedia C:\Users\MyUser -cdlabel MyUserBackup"
    Write-Output ""
    Write-Output "Options"
    Write-Output "-Verbose - Provide more feedback on script actions"
    Write-Output "-cdlabel <label> - Specify label to apply to media"
    Write-Output "-debuglevel <level> - Output diagnostic information. Level = 0 or 10"
    Write-Output "-production - Run in Production mode (CD-RWs not allowed)"
    Write-Output "-noCloseMedia - Do not close the media after writing"
    Write-Output "-recorderIndex <index> - Use the specified device (index is obtained from -list)"
    Write-Output "Commands"
    Write-Output "-driveletter - Display the writers drive letter"
    Write-Output "-getdrivestate - Display status of the current media"
    Write-Output "-getmediatype - Displays the type of media in the recorder"
    Write-Output "-mediatyperequired <media type> - Specify the type of media to be used in production mode"
    Write-Output "-getmediatypelist - Display the media types available"
    Write-Output "-help - Display this text"
    Write-Output "-list - Display a list of writeable drives"
    Write-Output "-writetomedia <sourcePath> - Write specified directory contents to media"
    Write-Output "-version - Display the product version number"
    Write-Output "-ejecttray - Eject the media from the drive"
}

# Respond to the caller
#
# Ouput format is 2 lines
#       <result>
#       <result message>
function Write-Response() {
    param (
        [switch] $success = $false,
        [switch] $failure = $false,
        [string] $message,
        [string] $response # Mandatory for non-error responses
    )
    if ( $failure ) {
        Write-Output "ERROR"
        Write-Output $message
    } elseif ( $success ){
        Write-Output $response
        Write-Output $message
    }
}

function Get-Version() {
    return "1.0.0-DEBUG"
}

function CDInterface() {
    [CmdletBinding()] param(
        [string]$writetomedia, 
        [string]$cdlabel,
        $recorderIndex = 0, 
        $mediaTypeRequired = 2,
        [switch]$noCloseMedia = $false,
        [switch]$list = $false,
        [switch]$driveletter = $false,
        [switch]$getdrivestate = $false,
        [switch]$getmediatype = $false,
        [switch]$getmediatypelist = $false,
        [switch]$production = $false,
        [switch]$help = $false,
        [switch]$version = $false,
        [switch]$ejecttray = $false,
        $debuglevel = -1
    )

    # Display version number
    if ( $version ) {
        $version = Get-Version
        Write-Response -success -message "Development release for initial testing" -response $version
    }

    $MediaTypeStrings = @(
        "IMAPI_MEDIA_TYPE_UNKNOWN",
        "IMAPI_MEDIA_TYPE_CDROM",
        "IMAPI_MEDIA_TYPE_CDR",
        "IMAPI_MEDIA_TYPE_CDRW",
        "IMAPI_MEDIA_TYPE_DVDROM",
        "IMAPI_MEDIA_TYPE_DVDRAM",
        "IMAPI_MEDIA_TYPE_DVDPLUSR",
        "IMAPI_MEDIA_TYPE_DVDPLUSRW",
        "IMAPI_MEDIA_TYPE_DVDPLUSR_DUALLAYER",
        "IMAPI_MEDIA_TYPE_DVDDASHR",
        "IMAPI_MEDIA_TYPE_DVDDASHRW",
        "IMAPI_MEDIA_TYPE_DVDDASHR_DUALLAYER",
        "IMAPI_MEDIA_TYPE_DISK",
        "IMAPI_MEDIA_TYPE_DVDPLUSRW_DUALLAYER",
        "IMAPI_MEDIA_TYPE_HDDVDROM",
        "IMAPI_MEDIA_TYPE_HDDVDR",
        "IMAPI_MEDIA_TYPE_HDDVDRAM",
        "IMAPI_MEDIA_TYPE_BDROM",
        "IMAPI_MEDIA_TYPE_BDR",
        "IMAPI_MEDIA_TYPE_BDRE",
        "IMAPI_MEDIA_TYPE_MAX"
    )

    if ( $help ) {
        Get-Usage
        return
    }

    if ( $writetomedia ) {
        if ( -Not $cdlabel ) {
            Write-Response -failure -message "-cdlabel option required with command -writetomedia"
            return
        }
    }

    if ( -Not ( $writetomedia -Or $list -Or $help -Or $driveletter -Or $getdrivestate -Or $getmediatype -Or $getmediatypelist -Or $ejecttray) ){
        Write-Response -failure -message "No command specified"
        Get-Usage
        return
    }

    $ok = $true

    # Collect options together
    $forceMediaToBeClosed = $true
    if ( $noCloseMedia ) {
        $forceMediaToBeClosed = $false
    }

    # Display media types this script knows about
    if ( $getmediatypelist ) {
        $counter = 0
        foreach ($mediaType in $MediaTypeStrings) {
            Write-Output "$counter $mediaType"
            $counter++
        }
        return
    }

    $dm = New-Object -ComObject "IMAPI2.MsftDiscMaster2"

    # Display available recorders
    if ( $list ) {
        Write-Verbose -Message "Number of recorders = $($dm.Count)"
        if ( $dm.Count -gt 1 ) {
            Write-Verbose -Message "The first drive is used by default, specify the -recorder option to use a different device"
        }

        if ( $dm.Count -ge 1 ) {
            $counter = 0
            foreach ($writer in $dm) {
                Write-Output "$counter $writer"
                $counter++
            }
        }
        return
    }

    # Is there a writeable drive(s) available ?
    if ( $dm.Count -eq 0 ) {
        Write-Response -failure -message "No Writeable drives available"
        return
    }

    # Is the specified recorder present ?
    if ( $recorderIndex -ge $dm.Count ) {
        Write-Response -failure -message "Specified recorder, $recorderIndex is not present. You have $($dm.Count) recorders"
        return
    }

    # Initialize the recorder:
    $recorder = New-Object -ComObject "IMAPI2.MsftDiscRecorder2"

    $recorder.InitializeDiscRecorder($dm.Item($recorderIndex))

    Write-Verbose -Message "Initialised recorder - Vendor ID $($recorder.VendorId) Product ID $($recorder.ProductId) on $($recorder.VolumePathNames)"

    if ( $ejecttray ) {
        try {
            $recorder.EjectMedia()
            Write-Response -success -message "Media ejected" -response "SUCCESS"
        } catch {
            Write-Response -failure -message "Media eject failed"
        }
        return
    }

    # Print drive letter disc writer is mounted on (only the first letter)
    if ( $driveletter ) {
        Write-Response -success -message "Drive is mounted on $($recorder.VolumePathNames[0])" -response $recorder.VolumePathNames[0][0]
        return
    }

    # Use formatter to permform media actions:
    $df2d = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
    $df2d.Recorder = $recorder
    $df2d.ClientName = "CDInterface"
    $df2d.ForceMediaToBeClosed = $forceMediaToBeClosed

    # What type of media is in the drive ?
    if ( $getmediatype ) {
        Write-Response -success -message $MediaTypeStrings[$df2d.CurrentPhysicalMediaType] -response $($df2d.CurrentPhysicalMediaType)
        return
    }

    if ( -Not $df2d.CurrentPhysicalMediaType ) {
        if ( $getdrivestate ) {
            Write-Response -success -message "No Media is loaded" -response "NO_DISC"
        } else {
            Write-Response -failure -message "No Media is loaded"
        }
        return
    } else {
        if ( $getmediatype ) {
            Write-Response -success -message $MediaTypeStrings[$df2d.CurrentPhysicalMediaType] -response $df2d.CurrentPhysicalMediaType
            return
        }
    }

    # Is there a writeable disc in the drive ?
    if ( -Not $df2d.IsCurrentMediaSupported($recorder) ) {
        if ( $getdrivestate ) {
            Write-Response -success -message "Non-writeable Media is loaded" -response "NON_WRITEABLE_DISC"
        } else {
            Write-Response -failure -message "Non-writeable Media is loaded"
        }
        return
    }

    # In production only specific media is acceptable
    if ( $production -And $df2d.CurrentPhysicalMediaType -ne $mediaTypeRequired ) {
        if ( $getdrivestate ) {
            Write-Response -success -message "Must be type $mediaTypeRequired $($MediaTypeStrings[$mediaTypeRequired]) in production" -response "INVALID_MEDIA"
        } else {
            Write-Response -failure -message "Must be type $mediaTypeRequired $($MediaTypeStrings[$mediaTypeRequired]) in production"
        }
        return
    }

    # We need an empty CD to write data to
    if ( $df2d.MediaHeuristicallyBlank ) { # Note a quick erased CD-RW is not physically blank!
        if ( $getdrivestate ) {
            Write-Response -success -message "Blank Media Loaded" -response "BLANK_CD"
            return
        }
    } else {
        if ( $getdrivestate ) {
            Write-Response -success -message "Disc is not empty" -response "NON_WRITEABLE_DISC"
        } else {
            Write-Response -failure -message "Disc must be blank"
        }
        if ( -Not $production ) {
            Write-Verbose -Message "Use erase option on RW media first"
        }
        $ok = $false
    }

    if ( $ok -And $writetomedia ) {
        # Create the in memory disc image:
        $fsi = New-Object -ComObject "IMAPI2FS.MsftFileSystemImage"

        $fsi.FileSystemsToCreate = 7

        $fsi.VolumeName = $cdlabel

        # Try to add the specified directory to the in memory file system
        Write-Verbose -Message "Adding contents of $writetomedia to burn image ..."
        try {
            $fsi.Root.AddTreeWithNamedStreams($writetomedia, $false)
        } catch {
            Write-Response -failure -message "Could not find path $writetomedia : $PSItem"
            $ok = $false
        }

        if ( $ok ) {
            Write-Verbose -Message "Creating iso disc image in memory ... "
            $resultimage = $fsi.CreateResultImage()

            $resultStream = $resultimage.ImageStream

            try {
                Write-Verbose -Message "Acquiring exclusive access to recorder ... "
                $recorder.AcquireExclusiveAccess($false,$df2d.ClientName);
                Write-Verbose -Message "Now burning the image ... "
                $df2d.Write($resultStream)
                Write-Verbose -Message "Ejecting the media ... "
                $recorder.EjectMedia()
                Write-Verbose -Message "Releasing exclusive access to recorder ... "
                $recorder.ReleaseExclusiveAccess()
                Write-Response -success -message "Media writing complete" -response "WRITE_SUCCESS"
            } catch {
                Write-Response -failure -message "Disc burning failed"
            }
        }
    }
}

Export-ModuleMember -Function CDInterface