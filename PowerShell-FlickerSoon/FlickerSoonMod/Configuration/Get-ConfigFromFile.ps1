function Get-ConfigFromFile {
    $config = Get-Content -Path $configPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    Write-Debug "Config loaded."
    if (![bool]$config) {
        New-ConfigFile
    } else {
        $requiredFields = @(
            @{ Name = "OMDb API Key"; Value = $config.Apis.OmdbApiKey },
            @{ Name = "TMDb API Key"; Value = $config.Apis.TmdbApiKey },
            @{ Name = "TMDb Bearer Token"; Value = $config.Apis.TmdbBearerToken },
            @{ Name = "OMDb Endpoint"; Value = $config.Endpoints.OmdbEndpoint },
            @{ Name = "TMDb Endpoint"; Value = $config.Endpoints.TmdbEndpoint }
        )
        $missingValues = $requiredFields | Where-Object { [string]::IsNullOrEmpty($_.Value) } | ForEach-Object { $_.Name }
        if ($missingValues.Count -gt 0) {
            Write-Error = "Failed to read configuration from file. The following fields are missing or empty: $($missingValues -join ', '). Please update config.json."
        } else {
            Write-Host "Config loaded"
            return $config
        }
    }  
}