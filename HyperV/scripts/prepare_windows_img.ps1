Param(
    [Parameter(Mandatory=$true)][string]$imageId,
    [string]$branchName='master'
)

Write-Host "Windows image id: $imageId"

$scriptLocation = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition)
. "$scriptLocation\config.ps1"
. "$scriptLocation\utils.ps1"


$baseImageDir = "C:\OpenStack\Instances\_base"

if (! (Test-Path $baseImageDir)) {
    mkdir $baseImageDir
}

Write-Host "Creating base Windows image."
new-vhd -Path "$baseImageDir\$imageId.vhdx" -ParentPath $windowsImagePath
