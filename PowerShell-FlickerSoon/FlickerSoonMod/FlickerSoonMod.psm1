# Import nested modules
foreach ($file in Get-ChildItem -filter *.ps1 -recurse -Path FlickerSoonMod) {
    . $file
}
