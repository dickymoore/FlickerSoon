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