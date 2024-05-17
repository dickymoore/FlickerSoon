function New-ConfigFile {
    $createConfig = Read-Host "Can't find Config File. Would you like to create one? (Y/N)"
    if ($createConfig -eq "Y" -or $createConfig -eq "y") {
        $template = Get-Content -Path "./config_template.json" -Raw | ConvertFrom-Json
        $config = @{
            Apis = @{ }
            Endpoints = @{ }
            Settings = @{ }
        }
        foreach ($section in $template.PSObject.Properties) {
            $sectionName = $section.Name
            $config[$sectionName] = @{}

            foreach ($setting in $section.Value.PSObject.Properties) {
                $settingName = $setting.Name
                $defaultValue = $setting.Value
                $newValue = Read-Host "Enter $settingName ($defaultValue)"
                $config[$sectionName][$settingName] = $newValue
            }
        }
        $config | ConvertTo-Json | Set-Content -Path $configPath
        Write-Host "Config file created successfully."
    }  else {
        Write-Error "Need config file or parameters."
    }
}