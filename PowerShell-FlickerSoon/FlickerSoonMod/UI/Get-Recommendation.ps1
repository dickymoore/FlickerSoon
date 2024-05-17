function Show-RecommendationsMenu {
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
            Show-RecommendationsMenu
        }
    }
    # return output to screen or csv or out-grid
    $recommendationSummary | Out-GridView
    pause # needs working - how to output it etc?

}