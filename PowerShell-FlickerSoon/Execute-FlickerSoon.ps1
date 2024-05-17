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

################################################
#
# 0. Source Modules
#
################################################

$ScriptPath = try {
    Split-Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue
} catch {
    Join-Path -Path $Env:reposPath -ChildPath "FlickerSoon\PowerShell-FlickerSoon\FlickerSoonMod"
}
Write-Debug "Running in $($scriptPath)"
Import-Module $(Join-Path -Path $scriptPath -ChildPath /FlickerSoonMod)

################################################
#
# 1. Get configuration from parameters or config
#
################################################

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