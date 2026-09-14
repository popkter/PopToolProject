param([Parameter(Mandatory)][string]$Archive,[Parameter(Mandatory)][string]$Destination,[string]$Prefix='')
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root=[IO.Path]::GetFullPath($Destination).TrimEnd('\')+'\'
function Assert-NoReparsePoint([string]$Path) {
    $part=$Path
    while($part) {
        if(([IO.Directory]::Exists($part) -or [IO.File]::Exists($part)) -and (([IO.File]::GetAttributes($part) -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { throw 'Extraction through a reparse point is not allowed' }
        $parent=[IO.Path]::GetDirectoryName($part.TrimEnd('\'))
        if($parent -eq $part) { break }
        $part=$parent
    }
}
Assert-NoReparsePoint $root
$package=[IO.Compression.ZipFile]::OpenRead($Archive)
try {
    $entries=@()
    foreach($entry in $package.Entries) {
        $name=$entry.FullName.Replace('\','/')
        if($Prefix -and -not $name.StartsWith($Prefix,[StringComparison]::Ordinal)) { continue }
        if($Prefix) { $name=$name.Substring($Prefix.Length) }
        if(-not $name) { continue }
        if($name.StartsWith('/') -or $name.Contains(':') -or ($name.Split('/') -contains '..')) { throw 'Archive contains an invalid path' }
        if((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Archive symlinks are not supported' }
        $target=[IO.Path]::GetFullPath([IO.Path]::Combine($root,$name))
        if(-not $target.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)) { throw 'Archive escapes target' }
        Assert-NoReparsePoint $target
        $entries+=@{Entry=$entry;Target=$target;Directory=$name.EndsWith('/')}
    }
    foreach($item in $entries) {
        if($item.Directory) { [IO.Directory]::CreateDirectory($item.Target) | Out-Null; continue }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Target)) | Out-Null
        [IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry,$item.Target,$true)
    }
} finally { $package.Dispose() }
