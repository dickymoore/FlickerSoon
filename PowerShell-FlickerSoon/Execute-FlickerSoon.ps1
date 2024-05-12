param (
    $OmdbApiKey = $null,
    $TmdbApiKey = $null,
    $TmdbBearerToken = $null,
    $OmdbEndpoint = $null,
    $TmdbEndpoint = $null,
    $lookAheadWeeks = $null,
    $includeAdult = $null,
    $Region = $null,
    $maxLimit = $null,
    $configPath = "./config.json"
)

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
        Write-Host "Need config file or parameters."
    }
}

# Get upcoming movies for the next X weeks using the discover endpoint
function Get-UpcomingMovies {
    param (
        [string]$tmdbApi,
        [string]$tmdbEndpoint,
        [int]$lookAheadWeeks,
        [string]$Region,
        [string]$includeAdult,
        [int]$maxLimit
    )

    $startDate = ((Get-Date).ToString("yyyy-MM-dd"))
    $endDate = ((Get-Date).AddDays(7 * $lookAheadWeeks).ToString("yyyy-MM-dd"))
    $apiUrl = "$($tmdbEndpoint)/3/discover/movie?api_key=$($tmdbApi)&primary_release_date.gte=$($startDate)&primary_release_date.lte=$($endDate)?include_adult=$([string]$includeAdult)&sort_by=popularity.desc"
    $pageTotal = [Math]::Ceiling(($maxLimit/20))
    $upcomingMovieList = for ($pageNumber = 1; $pageNumber -le $pageTotal; $pageNumber++) {
        try {
            Write-Debug "Calling for page $($pageNumber) out of $($pageTotal)"
            $apiReturn = Invoke-RestMethod -Uri "$($apiUrl)&page=$($pageNumber)" -Method Get
            if ($apiReturn.page -gt $apiReturn.total_pages) {
                Write-Debug "Requested more pages than available"
                break
            } else {
                $apiReturn
            }
        }
        catch {
            Write-Error "Failed to get upcoming movies for the next $WeeksAhead weeks from TMDb on page $($pageNumber): $_"
            return $null
        }
    }
    $genreList = try {
        ((Invoke-WebRequest -Uri "$($tmdbEndpoint)/3/genre/movie/list?api_key=$($tmdbApi)" -Method GET).Content | ConvertFrom-Json).genres
    } catch {
        Write-Error "Couldn't get Genres"
    }

    $upcomingMovies = foreach ($upcomingMovie in ($upcomingMovieList.results[0..($maxLimit-1)])) {
        Write-Debug "Retreiving credits for $($upcomingMovie.title)"
        $apiUrl = "$($tmdbEndpoint)/3/movie/$($upcomingMovie.id)/credits?api_key=$($tmdbApi)"
        try {
            $credits = Invoke-RestMethod -Uri $apiUrl -Method Get
            $upcomingMovie | Add-Member -MemberType NoteProperty -Name "Crew" -Value $credits.crew
            $upcomingMovie | Add-Member -MemberType NoteProperty -Name "Cast" -Value $credits.cast
            $upcomingMovie
        }
        catch {
            Write-Error "Failed to get credits for movie $($upcomingMovie.title): $_"
            return $null
        }
        $genreNames = foreach ($genreId in $upcomingMovie.genre_ids) {
            Write-Debug "Finding genre Id: $($genreId)"
            $genre = $genreList | Where-Object { $_.id -eq $genreId }
            Write-Debug "Found genre: $($genre.name)"
            $genre.name
        }
        $genres = $genreNames -join ', '
        $upcomingMovie | Add-Member -MemberType NoteProperty -Name "Genres" -Value $genres
        $upcomingMovie
    }
    $upcomingMovies
}

function Show-Menu {
    Write-Host @"
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣀⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⣠⣤⣤⣤⡀⠀⢀⣼⣿⣿⣿⣿⣿⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⣾⣿⣿⣿⣿⣿⡄⢸⣿⣿⣿⣿⣿⣿⣿⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⢿⣿⣿⣿⣿⣿⠃⠘⢿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠙⠛⠛⠛⠁⠀⠀⠀⠙⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⡆⢰⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⣶⡆⠀⠀⠀⢀⣀⣤⠀⠀⠀⠀
⠀⠀⠀⠀⠁⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢠⣴⣾⣿⣿⣿⠀⠀⠀⠀
⠀⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠈⠉⠛⠿⣿⣿⠀⠀⠀⠀

⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠸⣿⣿⢻⣟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣸⠃⣿⠈⢿⡄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⢰⡟⠀⣿⠀⠘⣷⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⢠⡿⠁⠀⣿⠀⠀⠘⣧⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
"@ -ForegroundColor Green
    Write-Host "FlickerSoon"
    Write-Host "___________"
    Write-Host "1. Show upcoming movies"
    Write-Host "2. Export upcoming movies to spreadsheet"
    Write-Host "3. Make recommendations"
    Write-Host "4. Exit"
    $choice = Read-Host "Enter your choice (1, 2, or 3)"
    switch ($choice) {
        "1" {
            Out-UpcomingMovies -movies $upcomingMovieList -Destination "Display"
        }
        "2" {
            Out-UpcomingMovies -movies $upcomingMovieList -Destination "Spreadsheet"
        }
        "3" {
            Get-Recommendations $upcomingMovieList
        }
        "4" {
            exit 0
        }
        default {
            Show-Menu
        }
    }
}

function Out-UpcomingMovies {
    param (
        $movies,
        $destination
    )
    $outView = foreach ($movie in $movies) {
        $directors = $movie.crew | Where-Object { $_.job -eq 'Director' } | Select-Object -ExpandProperty name
        $writers = $movie.crew | Where-Object { $_.job -eq 'Writer' } | Select-Object -ExpandProperty name
        $producers = $movie.crew | Where-Object { $_.job -eq 'Producer' } | Select-Object -ExpandProperty name
        
        $actors = $movie.Cast[0..2].name -join ', '
        $genres = $movie.Genres -join ', '
        
        [PSCustomObject]@{
            Title = $movie.Title
            Genres = $genres
            release_date = $movie.release_date
            Director = $directors -join ', '
            Writer = $writers -join ', '
            Producer = $producers -join ', '
            Actors = $actors
            overview = $movie.overview
        }
    }
    switch ($destination) {
        "Display" {
            $outView | Out-GridView
        }
        "SpreadSheet" {
            # Export CSV here
        }
        default {
            Write-Error "Unknown destination specified in Out-UpcomingMovies."
        }
    }
}

function Get-Recommendations {
    param ($movies)
    # Implement recommendation logic based on factors like recent IMDB ratings of the director, writer, actors, etc.
    Write-Host "Making recommendations..."
    # Example:
    # foreach ($movie in $movies) {
    #     $directorRating = Get-DirectorRating $movie.Crew
    #     $writerRating = Get-WriterRating $movie.Crew
    #     $actorsRating = Get-ActorsRating $movie.Cast
    #     Write-Host "Recommendation for $($movie.title): Director Rating - $directorRating, Writer Rating - $writerRating, Actors Rating - $actorsRating"
    # }
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
            OmdbApiKey = $OmdbApiKey
            TmdbApiKey = $TmdbApiKey
            TmdbBearerToken = $TmdbBearerToken
        }
        Endpoints = [PSCustomObject]@{
            OmdbEndpoint = $OmdbEndpoint
            TmdbEndpoint = $TmdbEndpoint
        }
        Settings = [PSCustomObject]@{
            $lookAheadWeeks = $lookAheadWeeks
            $includeAdult = $includeAdult
            $Region = $Region
            $maxLimit = $maxLimit
        }
    }
}

##########################
#
# 2. Get Upcoming Movies 
#
##########################

$upcomingMovieList = Get-UpcomingMovies `
    -tmdbApi $config.Apis.TmdbApiKey `
    -tmdbEndpoint $config.Endpoints.TmdbEndpoint `
    -lookAheadWeeks $config.Settings.lookAheadWeeks `
    -includeAdult $config.Settings.includeAdult `
    -Region $config.Settings.Region `
    -MaxLimit $config.Settings.MaxLimit

###########################
#
# Prompt for action
# 
###########################

Show-Menu










    $tmdbApi = $config.Apis.TmdbApiKey
    $tmdbEndpoint = $config.Endpoints.TmdbEndpoint
    $lookAheadWeeks = $config.Settings.lookAheadWeeks
    $includeAdult = $config.Settings.includeAdult
    $Region = $config.Settings.Region
    $MaxLimit = $config.Settings.MaxLimit








# # Build API URL based on parameters
# function Build-APIURL {
#     param($title, $year, $baseURL, $typeParam)
#     $apiURL = $baseURL
#     $apiURL += "t=" + [uri]::EscapeDataString($title)
#     if ($year -ne "") {
#         $apiURL += "&y=" + $year
#     }
#     if ($typeParam -ne "") {
#         $apiURL += "&type=" + $typeParam
#     }
#     return $apiURL
# }

# # Get data from the API
# function Get-Data {
#     param($title, $year, $baseURL, $apiKey, $typeParam)
    
#     $client = New-Object System.Net.WebClient
#     $client.Timeout = 10000  # 10 seconds
    
#     # Set the endpoint using the variables in the config file
#     $apiUrl = Build-APIURL -title "Civil War" -year "2024" -baseURL ($baseURL + $apiKey + "&") -typeParam "movie"
    
#     # Make an HTTP request
#     try {
#         $body = $client.DownloadString($apiUrl)
#     }
#     catch {
#         Write-Error "Failed to make HTTP request: $_"
#         return $null
#     }
    
#     # Print the response body
#     Write-Host "Response Body: $body"
    
#     # Process the data (for example, parse JSON)
#     try {
#         $data = ConvertFrom-Json $body
#     }
#     catch {
#         Write-Error "Failed to parse JSON: $_"
#         return $null
#     }
    
#     return $data
# }

# # Function to fetch data from TMDb using API key
# function Get-TmdbDataWithApiKey {
#     param (
#         [string]$MovieId,
#         [string]$ApiKey,
#         [string]$BaseURL
#     )

#     # Construct the API URL
#     $apiUrl = "$BaseURL$MovieId?api_key=$ApiKey"

#     # Make the HTTP request
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get
#         return $response
#     }
#     catch {
#         Write-Error "Failed to fetch data from TMDb with API key: $_"
#         return $null
#     }
# }

# function Get-TmdbDataWithBearerToken {
#     param (
#         [string]$MovieId,
#         [string]$BearerToken,
#         [string]$BaseURL
#     )

#     # Construct the API URL with the MovieId
#     $apiUrl = "$BaseURL/movie/$MovieId"

#     # Make the HTTP request with Bearer token
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "Authorization" = "Bearer $BearerToken" }
#         return $response
#     }
#     catch {
#         Write-Error "Failed to fetch data from TMDb with Bearer token: $_"
#         return $null
#     }
# }



# # Function to fetch upcoming movies from TMDb using bearer token
# function Get-UpcomingMoviesWithBearerToken {
#     param (
#         [string]$BearerToken,
#         [string]$BaseURL
#     )

#     # Construct the API URL for upcoming movies
#     $apiUrl = "$BaseURL/movie/upcoming"

#     # Make the API request with bearer token
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers @{ "Authorization" = "Bearer $BearerToken" }
#         return $response
#     }
#     catch {
#         Write-Error "Failed to fetch upcoming movies from TMDb: $_"
#         return $null
#     }
# }
# # Function to search for movies by title
# function Search-Movies {
#     param (
#         [string]$Query,
#         [string]$ApiKey,
#         [string]$BaseURL
#     )

#     # Construct the API URL for searching movies
#     $apiUrl = "$BaseURL/search/movie?query=$Query&api_key=$ApiKey"

#     # Make the API request
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get
#         return $response
#     }
#     catch {
#         Write-Error "Failed to search for movies on TMDb: $_"
#         return $null
#     }
# }

# # Function to fetch release dates for a movie
# function Get-MovieReleaseDates {
#     param (
#         [string]$MovieId,
#         [string]$ApiKey,
#         [string]$BaseURL
#     )

#     # Construct the API URL for fetching release dates
#     $apiUrl = "$BaseURL/movie/$MovieId/release_dates?api_key=$ApiKey"

#     # Make the API request
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get
#         return $response
#     }
#     catch {
#         Write-Error "Failed to fetch release dates for the movie from TMDb: $_"
#         return $null
#     }
# }
# # Get upcoming movies for the current year
# function Get-UpcomingMoviesForCurrentYear {
#     param (
#         [string]$Year,
#         [string]$ApiKey,
#         [string]$BaseURL
#     )

#     # Construct the API URL for searching movies
#     $apiUrl = "$BaseURL/discover/movie?primary_release_year=$Year&api_key=$ApiKey"

#     # Make the API request
#     try {
#         $response = Invoke-RestMethod -Uri $apiUrl -Method Get
#         return $response
#     }
#     catch {
#         Write-Error "Failed to get upcoming movies for the current year from TMDb: $_"
#         return $null
#     }=     exit 1
#  exit = $

# # Example: Get upcoming movies for the current year
# $config = Get-Configuration
# if (-not $config)
# }

# $currentYear = Get-Date -Format "yyyy"
# $upcomingMovies = Get-UpcomingMoviesForCurrentYear -Year $currentYear -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
# if (-not $upcomingMovies) {
#     Write-Host "No upcoming movies found for the current year."
# }
# else {
#     Write-Host "Upcoming movies for the current year:"
#     foreach ($movie in $upcomingMovies.results) {
#         Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
#     }
# }


# function Filter-UpcomingMovies {
#     param (
#         [array]$Movies
#     )

#     $today = Get-Date
#     $fourWeeksLater = $today.AddDays(28)

#     $filteredMovies = $Movies | Where-Object { ([DateTime]::Parse($_.release_date) -ge $today) -and ([DateTime]::Parse($_.release_date) -lt $fourWeeksLater) }

#     return $filteredMovies
# }
# ,
#  Write-Error = to load config"
# # Get-FutureFilms function
# function Get-FutureFilms {
#     $config = Get-Configuration
#     if (-not $config) {
#         Write-Error "Fail
#     }

#     $upcomingMovies = Get-UpcomingMoviesWithBearerToken -BearerToken $config.Apis.TmdbBearerToken -BaseURL $config.Endpoints.TmdbEndpoint
#     if (-not $upcomingMovies) {
#         exit 1
#     }

#     $filteredMovies = Filter-UpcomingMovies -Movies $upcomingMovies.results

#     # Print the filtered upcoming movies
#     if ($filteredMovies) {
#         Write-Host "Upcoming movies releasing in the next four weeks:"
#         foreach ($movie in $filteredMovies) {
#             Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
#         }
#     } else {
#         Write-Host "No upcoming movies found in the next four weeks."
#     }
# }
# ,
#  Write-Error = to load config"
# # Get-FutureFilms function
# function Get-FutureFilms {
#     $config = Get-Configuration
#     if (-not $config) {
#         Write-Error "Fail
#         return
#     }

#     $upcomingMovies = Get-UpcomingMovies -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint
#     if (-not $upcomingMovies) {
#         exit 1
#     }

#     $filteredMovies = Filter-UpcomingMovies -Movies $upcomingMovies.results

#     # Print the filtered upcoming movies
#     if ($filteredMovies) {
#         Write-Host "Upcoming movies releasing in the next four weeks:"
#         foreach ($movie in $filteredMovies) {
#             Write-Host "$($movie.title) - Release Date: $($movie.release_date)"
#         }
#     } else {
#         Write-Host "No upcoming movies found in the next four weeks."
#     }
#     # # Get data from OMDB
#     # $omdbData = Get-Data -title "Civil War" -year "2024" -baseURL $config.Endpoints.OmdbEndpoint -apiKey $config.Apis.OmdbApiKey -typeParam "movie"
#     # if (-not $omdbData) {
#     #     Write-Error "Failed to get data from OMDB API"
#     #     return
#     # }

#     # Get data from TMDb using API key
#     $tmdbDataWithApiKey = Get-TmdbDataWithApiKey -MovieId "11" -ApiKey $config.Apis.TmdbApiKey -BaseURL $config.Endpoints.TmdbEndpoint

#     if (-not $tmdbDataWithApiKey) {
#         Write-Error "Failed to get data from TMDb API with API key"
#         return
#     }

#     # Get data from TMDb using Bearer token
#     $tmdbDataWithBearerToken = Get-TmdbDataWithBearerToken -MovieId "11" -BearerToken $config.Apis.TmdbBearerToken -BaseURL $config.Endpoints.TmdbEndpoint
#     if (-not $tmdbDataWithBearerToken) {
#         Write-Error "Failed to get data from TMDb API with Bearer token"
#         return
#     }

#     # Print some information from the data
#     Write-Host "OMDB Data: $($omdbData | ConvertTo-Json -Depth 5)"
#     Write-Host "TMDb Data with API Key: $($tmdbDataWithApiKey | ConvertTo-Json -Depth 5)"
#     Write-Host "TMDb Data with Bearer Token: $($tmdbDataWithBearerToken | ConvertTo-Json -Depth 5)"
# }

# # Run Get-FutureFilms function
# Get-FutureFilms
