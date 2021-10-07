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

function Get-Usage() {
    Write-Host "Usage - CDInterface sourcePath [commands|options]"
    Write-Host "Examples"
    Write-Host "Write the contents of a directory to current media"
    Write-Host ""
    Write-Host "CDInterface -writetomedia C:\Users\MyUser -cdlabel MyUserBackup"
    Write-Host ""
    Write-Host "Options"
    Write-Host "-Verbose - Provide more feedback on script actions"
    Write-Host "-cdlabel <label> - Specify label to apply to media"
    Write-Host "-debuglevel <level> - Output diagnostic information. Level = 0 or 10"
    Write-Host "-production - Run in Production mode (CD-RWs not allowed)"
    Write-Host "-noCloseMedia - Do not close the media after writing"
    Write-Host "-recorderIndex <index> - Use the specified device (index is obtained from -list)"
    Write-Host "Commands"
    Write-Host "-driveletter - Display the writers drive letter"
    Write-Host "-getdrivestate - Display status of the current media"
    Write-Host "-getmediatype - Displays the type of media in the recorder"
    Write-Host "-mediatyperequired <media type> - Specify the type of media to be used in production mode"
    Write-Host "-getmediatypelist - Display the media types available"
    Write-Host "-help - Display this text"
    Write-Host "-list - Display a list of writeable drives"
    Write-Host "-writetomedia <sourcePath> - Write specified directory contents to media"
    Write-Host "-version - Display the product version number"
    Write-Host "-ejecttray - Eject the media from the drive"
}

# Choose the message to output when a fatal error has occurred
function Write-OutputError() {
    if ( $getdrivestate ) {
        Write-Output "UNKNOWN_ERROR"
    } elseif ( $ejecttray ) {
        Write-Output "FAILED"
    } elseif ( $writetomedia ) {
        Write-Output "WRITE_ERROR"
    } else {
        Write-Output "ERROR_OCCURRED"
    }
}

# Display version number
if ( $version ) {
    Write-Output "1.0.0-DEBUG"
    exit
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
    exit
}

if ( $writetomedia ) {
    if ( -Not $cdlabel ) {
        Write-OutputError
        Write-Verbose -Message "ERROR - -cdlabel option required with command -writetomedia"
        exit
    }
}

if ( -Not ( $writetomedia -Or $list -Or $help -Or $driveletter -Or $getdrivestate -Or $getmediatype -Or $getmediatypelist -Or $ejecttray) ){
    Write-Output "ERROR - no command specified"
    Get-Usage
    exit
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
    exit
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
            Write-Host $counter " " $writer
            $counter++
        }
        Write-Host ""
    }
    exit
}

# Is there a writeable drive(s) available ?
# Drive status requested
if ( $getdrivestate ) {
    if ( $dm.Count -eq 0 ) {
        exit
    }
}

if ( $dm.Count -eq 0 ) {
    Write-OutputError
    Write-Verbose -Message "ERROR - No Writeable drives available"
    exit
}

# Is the specified recorder present ?
if ( $recorderIndex -ge $dm.Count ) {
    Write-OutputError
    Write-Verbose -Message "ERROR - Specified recorder is not present"
    exit
}

#initialize the recorder:
$recorder = New-Object -ComObject "IMAPI2.MsftDiscRecorder2"

$recorder.InitializeDiscRecorder($dm.Item($recorderIndex))

Write-Verbose -Message "Initialised recorder - Vendor ID $($recorder.VendorId) Product ID $($recorder.ProductId) on $($recorder.VolumePathNames)"

if ( $ejecttray ) {
    try {
        $recorder.EjectMedia()
        Write-Output "SUCCESS"
        Write-Verbose -Message "Media ejected"
    } catch {
        Write-OutputError
        Write-Verbose -Message "Media eject failed"
    }
    exit
}

# Print drive letter disc writer is mounted on (only the first letter)
if ( $driveletter ) {
    Write-Output $recorder.VolumePathNames[0][0]
    exit
}

# Use formatter to permform media actions:
$df2d = New-Object -ComObject IMAPI2.MsftDiscFormat2Data
$df2d.Recorder = $recorder
$df2d.ClientName = "CDInterface"
$df2d.ForceMediaToBeClosed = $forceMediaToBeClosed

# What type of media is in the drive ?
if ( $getmediatype ) {
    Write-Output "$($df2d.CurrentPhysicalMediaType) $($MediaTypeStrings[$df2d.CurrentPhysicalMediaType])"
    exit
}

if ( -Not $df2d.CurrentPhysicalMediaType ) {
    if ( $getdrivestate ) {
        Write-Output "NO_DISC"
    } else {
        Write-OutputError "WRITE_ERROR"
    }
    Write-Verbose -Message "No Media is loaded"
    exit
} else {
    Write-Verbose -Message "Media loaded is type $($df2d.CurrentPhysicalMediaType) $($MediaTypeStrings[$df2d.CurrentPhysicalMediaType])"
}

# Is there a writeable disc in the drive ?
if ( -Not $df2d.IsCurrentMediaSupported($recorder) ) {
    if ( $getdrivestate ) {
        Write-Output "NON_WRITEABLE_DISC"
    } else {
        Write-OutputError
    }
    exit
}

# In production only specific media is acceptable
if ( $production -And $df2d.CurrentPhysicalMediaType -ne $mediaTypeRequired ) {
    if ( $getdrivestate ) {
        Write-Output "INVALID_MEDIA"
    } else {
        Write-OutputError
    }
    Write-Verbose -Message "Must be type $mediaTypeRequired $($MediaTypeStrings[$mediaTypeRequired]) in production"
    exit
}

# We need an empty CD to write data to
if ( $df2d.MediaHeuristicallyBlank ) { # Note a quick erased CD-RW is not physically blank!
    if ( $getdrivestate ) {
        Write-Output "BLANK_CD"
        exit
    }
} else {
    if ( $getdrivestate ) {
        Write-Output "NON_WRITEABLE_DISC"
    } else {
        Write-OutputError
    }
    if ( $production ) {
        Write-Verbose -Message "Disc is not blank."
    } else {
        Write-Verbose -Message "Disc is not blank. Use erase option on CD-RW media first"
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
        Write-OutputError
        Write-Verbose -Message "ERROR : Could not find path $writetomedia : $PSItem"
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
            Write-Verbose -Message "Media writing complete"
            Write-Output "WRITE_SUCCESS"
        } catch {
            Write-OutputError "WRITE_ERROR"
        }
    }
}