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