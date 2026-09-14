param([string]$OutputRoot)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
if(!$OutputRoot){$OutputRoot=Join-Path $projectRoot 'build/archive-validation'}
$testRoot=Join-Path ([IO.Path]::GetFullPath($OutputRoot)) ([Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$extractor=Join-Path $projectRoot 'resources/plugin-bootstrap/install-archive.ps1'
function New-Fixture([string]$Path,[string]$InvalidName,[bool]$Symlink=$false){
    $archive=[IO.Compression.ZipFile]::Open($Path,[IO.Compression.ZipArchiveMode]::Create)
    try{
        $entry=$archive.CreateEntry('normal.txt')
        $writer=New-Object IO.StreamWriter($entry.Open())
        try{$writer.Write('fixture')}finally{$writer.Dispose()}
        if($InvalidName){
            $entry=$archive.CreateEntry($InvalidName)
            if($Symlink){$entry.ExternalAttributes=[int](([int64]0xA1FF -shl 16)-4294967296)}
        }
    }finally{$archive.Dispose()}
}
$cases=@(
    @{Name='parent';Entry='../escape.txt';Message='invalid path'},
    @{Name='backslash';Entry='..\escape.txt';Message='invalid path'},
    @{Name='absolute';Entry='/escape.txt';Message='invalid path'},
    @{Name='drive';Entry='C:/escape.txt';Message='invalid path'},
    @{Name='stream';Entry='normal.txt:payload';Message='invalid path'},
    @{Name='symlink';Entry='link';Symlink=$true;Message='symlinks'}
)
foreach($case in $cases){
    $zip=Join-Path $testRoot ($case.Name+'.zip')
    $destination=Join-Path $testRoot $case.Name
    New-Fixture $zip $case.Entry ([bool]$case.Symlink)
    $rejected=$false
    try{& $extractor -Archive $zip -Destination $destination}catch{
        if(!$_.Exception.Message.Contains($case.Message)){throw}
        $rejected=$true
    }
    if(!$rejected){throw "Unsafe archive accepted: $($case.Name)"}
    if(Test-Path -LiteralPath (Join-Path $destination 'normal.txt')){throw 'Archive partially extracted before validation'}
    Write-Output "PASS $($case.Name)"
}
$validZip=Join-Path $testRoot 'valid.zip'
New-Fixture $validZip ''
$validDestination=Join-Path $testRoot 'valid'
& $extractor -Archive $validZip -Destination $validDestination
if([IO.File]::ReadAllText((Join-Path $validDestination 'normal.txt')) -ne 'fixture'){throw 'Valid archive did not extract correctly'}
Write-Output 'PASS valid archive'
Write-Output "Fixtures: $testRoot"
