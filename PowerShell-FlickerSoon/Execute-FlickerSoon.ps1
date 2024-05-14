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
    $yearRange = $null,
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
        Write-Error "Need config file or parameters."
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
    }
    $upcomingMovies
}

function Show-Menu {
    param (
        $config,
        $upcomingMovieList
    )
    Clear-Host
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
    Write-Host "FlickerSoon
___________
1. Show upcoming movies
2. Export upcoming movies to spreadsheet
3. Make recommendations
4. Exit" -ForegroundColor Yellow
    $choice = Read-Host "Enter your choice"
    switch ($choice) {
        "1" {
            Out-UpcomingMovies -movies $upcomingMovieList -Destination "Display"
        }
        "2" {
            Out-UpcomingMovies -movies $upcomingMovieList -Destination "Spreadsheet"
        }
        "3" {
            Get-Recommendations -upcomingMovieList $upcomingMovieList -config $config
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
            $csvPath = ".\FlickerSoon-Upcoming-$((Get-Date).ToString("yyyyMMddHHss")).csv"
            $outView | Export-Csv -Path $csvPath -NoTypeInformation
            Start-Process -FilePath $csvPath            
        }
        default {
            Write-Error "Unknown destination specified in Out-UpcomingMovies."
        }
    }
}

function Get-PersonSummary {
    param (
        $ProjectsSummary
    )
    $movieSummary = [PSCustomObject]@{
        Role = ""
        Name = ""
        Credits = 0
        TotalIMDBRating = 0
        TotalRottenTomatoesRating = 0
        MaxIMDBRating = 0
        MaxRottenTomatoesRating = 0
        AverageIMDBRating = 0
        AverageRottenTomatoesRating = 0
        TotalBoxOffice = 0
        AverageBoxOffice = 0
    }
    $uniqueTitles = New-Object System.Collections.Generic.HashSet[string]

    foreach ($project in $ProjectsSummary) {
        Write-Debug "Credits processed: $($movieSummary.Credits)"
        $role = $project.Role
        if ($uniqueTitles.Contains($project.Title)) {
            Write-Debug "$($project.Title) already processed"
            continue
        } else {
            Write-Debug "$($project.Title) not yet processed"
            $uniqueTitles.Add($project.Title) > $null
        }
        $movieSummary.Role = $role
        $movieSummary.Name = $project.Name
        $movieSummary.Credits++
        $movieSummary.TotalIMDBRating += $project.IMDB_Rating
        $movieSummary.TotalRottenTomatoesRating += $project.Rotten_Tomatoes_Rating

        if ($project.IMDB_Rating -gt $movieSummary.MaxIMDBRating) {
            $movieSummary.MaxIMDBRating = $project.IMDB_Rating
        }

        if ($project.Rotten_Tomatoes_Rating -gt $movieSummary.MaxRottenTomatoesRating) {
            $movieSummary.MaxRottenTomatoesRating = $project.Rotten_Tomatoes_Rating
        }
        if ($project.BoxOffice -gt 0) {
            $movieSummary.TotalBoxOffice += $project.BoxOffice
        }
    }
    $movieSummary.AverageIMDBRating = if ($movieSummary.Credits -ne 0) { [math]::Round($movieSummary.TotalIMDBRating / $movieSummary.Credits) } else { 0 }
    $movieSummary.AverageRottenTomatoesRating = if ($movieSummary.Credits -ne 0) { [math]::Round($movieSummary.TotalRottenTomatoesRating / $movieSummary.Credits) } else { 0 }
    $movieSummary.AverageBoxOffice = if ($movieSummary.Credits -ne 0) { [math]::Round($movieSummary.TotalBoxOffice / $movieSummary.Credits)} else { 0 }

    $movieSummary
}

function New-Recommendations {
    param (
        $movies,
        $config,
        $recommendationType,
        $tmdbEndpoint = $config.Endpoints.TmdbEndpoint,
        $tmdbApi = $config.Apis.TmdbApiKey,
        $OmdbEndpoint = $config.Endpoints.OmdbEndpoint,
        $OmdbApi = $config.Apis.OmdbApiKey,
        $yearRange = $config.Settings.YearRange
    )
    Write-Debug "
        New-Recommendations
        `$movies = $($movies | Measure-Object).count
        `$config = $($config)
        `$recommendationType = $($recommendationType)
        `$tmdbEndpoint =$tmdbEndpoint
        `$tmdbApi = $($tmdbApi)
        `$OmdbEndpoint = $($OmdbEndpoint)
        `$OmdbApi = $($OmdbApi)
        `$yearRange = $($yearRange)
        )
    "
    $recommendationSummary = foreach ($movie in $movies) {
        Write-Debug "Processing movie: $($movie.title)"
        Write-Debug "Getting all people with the specified role"
        $people = $movie.Cast + $movie.Crew | Where-Object { $_.job -eq $recommendationType }
        Write-Debug "Found $(($people | Measure-Object).count) people with the $($recommendationType) role: $($people.name)"
        $processedMovies = @()
        $peopleSummaries = foreach ($person in $people) {
            Write-Debug "Looking for credits for: $($person.name) with ID: $($person.id)"
            Write-Debug "`$tmdbResponse = ((Invoke-WebRequest -Uri `"$($tmdbEndpoint)/3/person/$($person.id)/combined_credits?api_key=$($tmdbApi)`" -Method GET).Content | ConvertFrom-Json)"
            $tmdbResponse = ((Invoke-WebRequest -Uri "$($tmdbEndpoint)/3/person/$($person.id)/combined_credits?api_key=$($tmdbApi)" -Method GET).Content | ConvertFrom-Json)
            $personInfoAll = $tmdbResponse.cast + $tmdbResponse.crew  | Where-Object -Property job -eq $recommendationType
            $personInfoMovieOnly = $personInfoAll | Where-Object {
                ($_.media_type -eq "movie")
            }
            $personInfoHistoric = $personInfoMovieOnly | Where-Object {
                $_.release_date
            } | Where-Object {
                ([datetime]::Parse($_.release_date) -lt (Get-Date).AddDays(-1))
            }
            $projectsSummary = foreach ($personProject in ($personInfoHistoric)) {
                $projectObject = [PSCustomObject]@{}
                if ($person.name) { 
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $person.name 
                } else {
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Name" -Value "Error"
                }
                if ($person.id) { 
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Person_id" -Value $person.id 
                } else {
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Person_id" -Value 0
                }
                if ($personProject.job) { 
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Role" -Value $personProject.job 
                } else {
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Role" -Value 0
                }
                if (!($processedMovies -contains $personProject.title)) {
                    $processedMovies += $personProject.title
                    if ($personProject.title) { 
                        $projectObject | Add-Member -MemberType NoteProperty -Name "Title" -Value $personProject.title 
                    } else {
                        $projectObject | Add-Member -MemberType NoteProperty -Name "Title" -Value 0
                    }
                    
                    if ($personProject.release_date) { 
                        $projectObject | Add-Member -MemberType NoteProperty -Name "Release_date" -Value $personProject.release_date 
                    } else {
                        $projectObject | Add-Member -MemberType NoteProperty -Name "Release_date" -Value 0
                    }
                    try {
                        $movieTitle = $projectObject.Title -replace ' ','+'
                        $year = (Get-Date $personProject.release_date).Year
                    
                        $url = "$OmdbEndpoint/?apikey=$omdbApi&t=$movieTitle&y=$year"
                        $response = Invoke-RestMethod -Uri $url -Method GET
                        if ($response.Error -eq "Movie not found!") {
                            Write-Debug "Movie $($movieTitle) not found in $year. Trying adjacent years within the range: $($yearRange)."
                            for ($i = ($year - [math]::Round($yearRange/2)); $i -le ($year + [math]::Round($yearRange/2)); $i++) {
                                if ($i -ne $year) {
                                    $url = "$OmdbEndpoint/?apikey=$OmdbApi&t=$movieTitle&y=$i"
                                    $responseTemp = Invoke-RestMethod -Uri $url -Method GET
                                    
                                    Write-Debug "If movie found in an adjacent year, update response and exit the loop"
                                    if (!($responseTemp.Response -eq "False")) {
                                        $response = $responseTemp
                                        Write-Debug "Movie $($movieTitle) found in year $i."
                                        break
                                    }
                                }
                            }
                        }
                        if ($response.Response -eq "True") {
                            $imdbRating = if ($response.Ratings | Where-Object -property Source -eq "Internet Movie Database") { [math]::Round((($response.Ratings | Where-Object { $_.Source -eq "Internet Movie Database" }).Value).replace('/10','') / 10 * 100)} else {0}
                            $rottenTomatoesRating = if ($response.Ratings | Where-Object -property Source -eq "Rotten Tomatoes") {(($response.Ratings | Where-Object { $_.Source -eq "Rotten Tomatoes" }).Value).replace('%','')} else {0}
                            [int]$boxOffice = if ([bool]($response.BoxOffice -as [int])) {($response.BoxOffice).replace(',','').replace('$','')} else {0}
                        } else {
                            $imdbRating = 0
                            $rottenTomatoesRating = 0
                            [int]$boxOffice = 0
                        }
                    } catch {
                        $imdbRating = 0
                        $rottenTomatoesRating = 0
                        [int]$boxOffice = 0
                    }
                    $projectObject | Add-Member -MemberType NoteProperty -Name "IMDB_Rating" -Value $imdbRating
                    $projectObject | Add-Member -MemberType NoteProperty -Name "Rotten_Tomatoes_Rating" -Value $rottenTomatoesRating
                    $projectObject | Add-Member -MemberType NoteProperty -Name "BoxOffice" -Value $boxOffice
                    $projectObject
                } else {
                    Write-Debug "Historic movie: $($personProject.title) has already been processed under another person who worked on new release movie: $($movie.title) with the role: $($recommendationType).
                    This can happen if people with the role: $($recommendationType) work together repeatedly."
                    $projectObject
                }
            }
            $personSummary = Get-PersonSummary -ProjectsSummary $projectsSummary
            $personSummary | Add-Member NoteProperty -Name UpcomingMovie -Value $($movie.title)
            $personSummary
        }
        if (($peopleSummaries | Measure-Object).Count -gt 1) {

            $averageIMDBRatingEntryTotal = 0
            $averageIMDBRatingCount = 0
            foreach ($entry in $peopleSummaries.AverageIMDBRating | Where-Object {$_ -ne 0}) {
                $averageIMDBRatingEntryTotal += $entry
                $averageIMDBRatingCount++
            }
            $averageIMDBRating = if ($averageIMDBRatingCount -gt 0) {
                $($averageIMDBRatingEntryTotal/$averageIMDBRatingCount)
            } else {
                $averageIMDBRatingEntryTotal
            }
            # [math]::Round(($peopleSummaries.AverageIMDBRating | Measure-Object -Average).Average, 2)
            $averageRottenTomatoesRatingEntryTotal = 0
            $averageRottenTomatoesRatingCount = 0
            foreach ($entry in $peopleSummaries.AverageRottenTomatoesRating | Where-Object {$_ -ne 0}) {
                $averageRottenTomatoesRatingEntryTotal += $entry
                $averageRottenTomatoesRatingCount++
            }
            $averageRottenTomatoesRating = if ($averageRottenTomatoesRatingCount -gt 0) {
                $($averageRottenTomatoesRatingEntryTotal/$averageRottenTomatoesRatingCount)
            } else {
                $averageRottenTomatoesRatingEntryTotal
            }
            # [math]::Round(($peopleSummaries.AverageRottenTomatoesRating | Measure-Object -Average).Average, 2)
            $averageBoxOfficeEntryTotal = 0
            $averageBoxOfficeCount = 0
            foreach ($entry in $peopleSummaries.AverageBoxOffice | Where-Object {$_ -ne 0}) {
                $averageBoxOfficeEntryTotal += $entry
                $averageBoxOfficeCount++
            }
            $averageBoxOffice = if ($averageBoxOfficeCount -gt 0) {
                $($averageBoxOfficeEntryTotal/$averageBoxOfficeCount)
            } else {
                $averageBoxOfficeEntryTotal
            }
            # [math]::Round(($peopleSummaries.AverageBoxOffice | Measure-Object -Average).Average, 2)

            $mergedPerson = New-Object PSObject -Property @{
                Role = $peopleSummaries[0].Role
                Name = ($peopleSummaries.Name -join ' & ')
                Credits = ($peopleSummaries.Credits | Measure-Object -Sum).Sum
                TotalIMDBRating = ($peopleSummaries.TotalIMDBRating | Measure-Object -Sum).Sum
                TotalRottenTomatoesRating = ($peopleSummaries.TotalRottenTomatoesRating | Measure-Object -Sum).Sum
                MaxIMDBRating = ($peopleSummaries.MaxIMDBRating | Measure-Object -Maximum).Maximum
                MaxRottenTomatoesRating = ($peopleSummaries.MaxRottenTomatoesRating | Measure-Object -Maximum).Maximum
                TotalBoxOffice = ($peopleSummaries.TotalBoxOffice | Measure-Object -Sum).Sum
                UpcomingMovie = $peopleSummaries[0].UpcomingMovie
                AverageIMDBRating = $averageIMDBRating
                AverageRottenTomatoesRating = $averageRottenTomatoesRating
                AverageBoxOffice = $averageBoxOffice
                
            }
            # Output the merged person
            $mergedPerson
        } else {
            # If there's only one person, return it as is
            $peopleSummaries
        }
    }
    $recommendationSummary
}

function Get-Recommendations {
    param (
        $movies,
        $config
    )
    Clear-Host
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
    Write-Host "FlickerSoon Recommendations
___________________________
1. Recommend based on Director
2. Recommend based on Writer
3. Recommend on Producer
4. Recommend on Actor
5. Back to Main Menu." -ForegroundColor Yellow

    $choice = Read-Host "Enter your choice"
    switch ($choice) {
        "1" {
            $recommendationSummary = New-Recommendations -movies $movies -config $config -recommendationType "Director"
        }
        "2" {
            $recommendationSummary = New-Recommendations -movies $movies -config $config -recommendationType "Writer" # Needs fixing
        }
        "3" {
            $recommendationSummary = New-Recommendations -movies $movies -config $config -recommendationType "Producer"
        }
        "4" {
            $recommendationSummary = New-Recommendations -movies $movies -config $config -recommendationType "Actor" # Needs fixing
        }
        "5" {
            return
        }
        default {
            Get-Recommendations
        }
    }
    # return output to screen or csv or out-grid
    $recommendationSummary | Out-GridView
    pause # needs working - how to output it etc?
    
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
            $yearRange = $yearRange
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

while ($true) {
    Show-Menu -config $config -upcomingMovieList $upcomingMovieList
}







    $tmdbApi = $config.Apis.TmdbApiKey
    $tmdbEndpoint = $config.Endpoints.TmdbEndpoint
    $lookAheadWeeks = $config.Settings.lookAheadWeeks
    $includeAdult = $config.Settings.includeAdult
    $Region = $config.Settings.Region
    $MaxLimit = $config.Settings.MaxLimit
    $yearRange = $config.Settings.YearRange
    $movies = $upcomingMovieList