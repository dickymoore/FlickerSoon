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