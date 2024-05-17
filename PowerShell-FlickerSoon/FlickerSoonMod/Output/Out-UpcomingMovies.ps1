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