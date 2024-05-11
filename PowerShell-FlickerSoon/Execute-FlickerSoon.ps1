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
            @{ Name = "TMDb Bearer Token"; Value = $config.Apis.TmdbBearerToken },
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

# Function to fetch data from TMDb using API key
function Get-TmdbDataWithApiKey {
    param (
        [string]$MovieId,
        [string]$ApiKey,
        [string]$BaseURL
    )

    # Construct the API URL
    $apiUrl = "$BaseURL$MovieId?api_key=$ApiKey"

    # Make the HTTP request
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to fetch data from TMDb with API key: $_"
        return $null
    }
}

# Function to fetch data from TMDb using Bearer token
function Get-TmdbDataWithBearerToken {
    param (
        [string]$MovieId,
        [string]$BearerToken,
        [string]$BaseURL
    )

    # Make the HTTP request with Bearer token
    try {
        $response = Invoke-RestMethod -Uri $BaseURL -Method Get -Headers @{ "Authorization" = "Bearer $BearerToken" }
        return $response
    }
    catch {
        Write-Error "Failed to fetch data from TMDb with Bearer token: $_"
        return $null
    }
}

# Get-FutureFilms function
function Get-FutureFilms {
    $config = Read-Configuration
    if (-not $config) {
        Write-Error "Failed to load config"
        return
    }

    # # Get data from OMDB
    # $omdbData = Get-Data -title "Civil War" -year "2024" -baseURL $config.Endpoints.OmdbEndpoint -apiKey $config.Apis.OmdbApiKey -typeParam "movie"
    # if (-not $omdbData) {
    #     Write-Error "Failed to get data from OMDB API"
    #     return
    # }

    # Get data from TMDb using API key
    $tmdbDataWithApiKey = Get-TmdbDataWithApiKey -MovieId "11" -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
    if (-not $tmdbDataWithApiKey) {
        Write-Error "Failed to get data from TMDb API with API key"
        return
    }

    # Get data from TMDb using Bearer token
    $tmdbDataWithBearerToken = Get-TmdbDataWithBearerToken -MovieId "11" -BearerToken $config.Apis.TmdbBearerToken -BaseURL $config.Endpoints.TmdbEndpoint
    if (-not $tmdbDataWithBearerToken) {
        Write-Error "Failed to get data from TMDb API with Bearer token"
        return
    }

    # Print some information from the data
    Write-Host "OMDB Data: $($omdbData | ConvertTo-Json -Depth 5)"
    Write-Host "TMDb Data with API Key: $($tmdbDataWithApiKey | ConvertTo-Json -Depth 5)"
    Write-Host "TMDb Data with Bearer Token: $($tmdbDataWithBearerToken | ConvertTo-Json -Depth 5)"
}

# Run Get-FutureFilms function
Get-FutureFilms
