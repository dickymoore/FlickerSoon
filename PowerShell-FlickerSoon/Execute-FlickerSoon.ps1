param (
    $OmdbApiKey = $null,
    $TmdbApiKey = $null,
    $TmdbBearerToken = $null,
    $OmdbEndpoint = $null,
    $TmdbEndpoint = $null,
    $configPath = "./config.json"
)

function Get-ConfigFromFile {
    $config = Get-Content -Path $configPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
    Write-Debug "Config loaded."
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



# Get upcoming movies for the next X weeks using the discover endpoint
function Get-UpcomingMoviesForNextXWeeks {
    param (
        [int]$WeeksAhead,
        [string]$ApiKey,
        [string]$BaseURL
    )

    # Calculate the date range for the next X weeks
    $startDate = (Get-Date).AddDays(7 * $WeeksAhead)
    $endDate = $startDate.AddDays(7)

    # Format the dates for the API request
    $startDateString = $startDate.ToString("yyyy-MM-dd")
    $endDateString = $endDate.ToString("yyyy-MM-dd")

    # Construct the API URL for discovering movies released in the next X weeks
    $apiUrl = "$BaseURL/discover/movie?api_key=$ApiKey&primary_release_date.gte=$startDateString&primary_release_date.lte=$endDateString"

    # Make the API request
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to get upcoming movies for the next $WeeksAhead weeks from TMDb: $_"
        return $null
    }=     exit 1
 exit = $
$weeksAhead = 4  # Modify the number of weeks ahead as needed
$upcomingMovies = Get-UpcomingMoviesForNextXWeeks -WeeksAhead $weeksAhead -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
if (-not $upcomingMovies) {
    Write-Host "No upcoming movies found for the next $weeksAhead weeks."
}
else {
    Write-Host "Upcoming movies for the next $weeksAhead weeks:"
    foreach ($movie in $upcomingMovies.results) {
        Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
    }
}



#######################
#
# 1. Get configuration 
#
#######################

$nullParameter = $PSBoundParameters.GetEnumerator() | Where-Object { $null -eq $_.Value }
$config = if (![bool]$nullParameter) {
    Get-ConfigFromFile
} else {
    $config = [PSCustomObject]@{
        Apis = [PSCustomObject]@{
            OmdbApiKey = $null
            TmdbApiKey = $null
            TmdbBearerToken = $null
        }
        Endpoints = [PSCustomObject]@{
            OmdbEndpoint = $null
            TmdbEndpoint = $null
        }
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

function Get-TmdbDataWithBearerToken {
    param (
        [string]$MovieId,
        [string]$BearerToken,
        [string]$BaseURL
    )

    # Construct the API URL with the MovieId
    $apiUrl = "$BaseURL/movie/$MovieId"

    # Make the HTTP request with Bearer token
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "Authorization" = "Bearer $BearerToken" }
        return $response
    }
    catch {
        Write-Error "Failed to fetch data from TMDb with Bearer token: $_"
        return $null
    }
}



# Function to fetch upcoming movies from TMDb using bearer token
function Get-UpcomingMoviesWithBearerToken {
    param (
        [string]$BearerToken,
        [string]$BaseURL
    )

    # Construct the API URL for upcoming movies
    $apiUrl = "$BaseURL/movie/upcoming"

    # Make the API request with bearer token
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "Authorization" = "Bearer $BearerToken" }
        return $response
    }
    catch {
        Write-Error "Failed to fetch upcoming movies from TMDb: $_"
        return $null
    }
}
# Function to search for movies by title
function Search-Movies {
    param (
        [string]$Query,
        [string]$ApiKey,
        [string]$BaseURL
    )

    # Construct the API URL for searching movies
    $apiUrl = "$BaseURL/search/movie?query=$Query&api_key=$ApiKey"

    # Make the API request
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to search for movies on TMDb: $_"
        return $null
    }
}

# Function to fetch release dates for a movie
function Get-MovieReleaseDates {
    param (
        [string]$MovieId,
        [string]$ApiKey,
        [string]$BaseURL
    )

    # Construct the API URL for fetching release dates
    $apiUrl = "$BaseURL/movie/$MovieId/release_dates?api_key=$ApiKey"

    # Make the API request
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to fetch release dates for the movie from TMDb: $_"
        return $null
    }
}
# Get upcoming movies for the current year
function Get-UpcomingMoviesForCurrentYear {
    param (
        [string]$Year,
        [string]$ApiKey,
        [string]$BaseURL
    )

    # Construct the API URL for searching movies
    $apiUrl = "$BaseURL/discover/movie?primary_release_year=$Year&api_key=$ApiKey"

    # Make the API request
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Get
        return $response
    }
    catch {
        Write-Error "Failed to get upcoming movies for the current year from TMDb: $_"
        return $null
    }=     exit 1
 exit = $

# Example: Get upcoming movies for the current year
$config = Get-Configuration
if (-not $config)
}

$currentYear = Get-Date -Format "yyyy"
$upcomingMovies = Get-UpcomingMoviesForCurrentYear -Year $currentYear -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
if (-not $upcomingMovies) {
    Write-Host "No upcoming movies found for the current year."
}
else {
    Write-Host "Upcoming movies for the current year:"
    foreach ($movie in $upcomingMovies.results) {
        Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
    }
}


function Filter-UpcomingMovies {
    param (
        [array]$Movies
    )

    $today = Get-Date
    $fourWeeksLater = $today.AddDays(28)

    $filteredMovies = $Movies | Where-Object { ([DateTime]::Parse($_.release_date) -ge $today) -and ([DateTime]::Parse($_.release_date) -lt $fourWeeksLater) }

    return $filteredMovies
}
,
 Write-Error = to load config"
# Get-FutureFilms function
function Get-FutureFilms {
    $config = Get-Configuration
    if (-not $config) {
        Write-Error "Fail
    }

    $upcomingMovies = Get-UpcomingMoviesWithBearerToken -BearerToken $config.Apis.TmdbBearerToken -BaseURL $config.Endpoints.TmdbEndpoint
    if (-not $upcomingMovies) {
        exit 1
    }

    $filteredMovies = Filter-UpcomingMovies -Movies $upcomingMovies.results

    # Print the filtered upcoming movies
    if ($filteredMovies) {
        Write-Host "Upcoming movies releasing in the next four weeks:"
        foreach ($movie in $filteredMovies) {
            Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
        }
    } else {
        Write-Host "No upcoming movies found in the next four weeks."
    }
}
,
 Write-Error = to load config"
# Get-FutureFilms function
function Get-FutureFilms {
    $config = Get-Configuration
    if (-not $config) {
        Write-Error "Fail
        return
    }

    $upcomingMovies = Get-UpcomingMovies -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
    if (-not $upcomingMovies) {
        exit 1
    }

    $filteredMovies = Filter-UpcomingMovies -Movies $upcomingMovies.results

    # Print the filtered upcoming movies
    if ($filteredMovies) {
        Write-Host "Upcoming movies releasing in the next four weeks:"
        foreach ($movie in $filteredMovies) {
            Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
        }
    } else {
        Write-Host "No upcoming movies found in the next four weeks."
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
