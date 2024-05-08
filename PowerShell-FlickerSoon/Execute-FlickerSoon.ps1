# Read configuration from config.json
function Read-Configuration {
    param (
        $configPath = "./config.json"
    )
    $config = Get-Content -Path $configPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    Write-Host "Config loaded."
    if ([bool]$config) {
        $requiredFields = @(
            @{ Name = "OMDb API Key"; Value = $config.Apis.OmdbApiKey },
            @{ Name = "TMDb API Key"; Value = $config.Apis.TmdbApiKey },
            @{ Name = "OMDb Endpoint"; Value = $config.Endpoints.OmdbEndpoint },
            @{ Name = "TMDb Endpoint"; Value = $config.Endpoints.TmdbEndpoint }
        )
    
        $missingValues = $requiredFields | Where-Object { [string]::IsNullOrEmpty($_.Value) } | ForEach-Object { $_.Name }
    
        if ($missingValues.Count -gt 0) {
            $errorMessage = "Failed to read configuration from file. The following fields are missing or empty: $($missingValues -join ', '). Please update config.json."
            Write-Error $errorMessage
        } else {
            Write-Host "Config loaded"
            return $config
        }
    } else {
        Write-Error "Failed to read configuration file. Have you created config.json from the template config_template.json?"
    }
}

# Build API URL based on parameters
function Build-APIURL {
    param($title, $year, $baseURL, $typeParam)
    $apiURL = $baseURL
    $apiURL += "t=" + [uri]::EscapeDataString($title)
    if ($year -ne "") {
        $apiURL += "&y=" + $year
    }
    if ($typeParam -ne "") {
        $apiURL += "&type=" + $typeParam
    }
    return $apiURL
}

# Get data from the API
function Get-Data {
    param($title, $year, $baseURL, $apiKey, $typeParam)
    
    $client = New-Object System.Net.WebClient
    $client.Timeout = 10000  # 10 seconds
    
    # Set the endpoint using the variables in the config file
    $apiUrl = Build-APIURL -title "Civil War" -year "2024" -baseURL ($baseURL + $apiKey + "&") -typeParam "movie"
    
    # Make an HTTP request
    try {
        $body = $client.DownloadString($apiUrl)
    }
    catch {
        Write-Error "Failed to make HTTP request: $_"
        return $null
    }
    
    # Print the response body
    Write-Host "Response Body: $body"
    
    # Process the data (for example, parse JSON)
    try {
        $data = ConvertFrom-Json $body
    }
    catch {
        Write-Error "Failed to parse JSON: $_"
        return $null
    }
    
    return $data
}

# Main function
function Main {
    # Load configuration
    $config = Read-Configuration
    if (-not $config) {
        Write-Error "Failed to load config"
        return
    }

    # Get data from the API
    $data = Get-Data -title "Civil War" -year "2024" -baseURL $config.Endpoints.OmdbEndpoint -apiKey $config.Apis.OmdbApiKey -typeParam "movie"
    if (-not $data) {
        Write-Error "Failed to get data from API"
        return
    }

    # Print some information from the data
    Write-Host "Title: $($data.Title)"
    Write-Host "Year: $($data.Year)"
}

# Run main function
Main
