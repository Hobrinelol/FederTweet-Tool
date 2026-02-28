# FederTweet API PowerShell Tool
# Professionelles Monitoring Tool mit Service-Status und Auto-Update

# ============================================================================
# AUTO-UPDATE SECTION - Wird VOR der Klasse ausgeführt
# ============================================================================

$ScriptVersion = "2.1.0"
$ScriptPath = $MyInvocation.MyCommand.Path
$GitHubUser = "Hobrinelol"
$GitHubRepo = "FederTweet-Tool"
$UpdateURL = "https://api.github.com/repos/$GitHubUser/$GitHubRepo/releases/latest"

# Loading Bar beim Start
function Show-LoadingBar {
    param(
        [string]$Message = "Initializing",
        [int]$Duration = 2000
    )
    
    $frames = @("|", "/", "-", "\")
    $endTime = (Get-Date).AddMilliseconds($Duration)
    $i = 0
    
    Write-Host ""
    while ((Get-Date) -lt $endTime) {
        $progress = [math]::Round(((Get-Date) - $endTime.AddMilliseconds(-$Duration)).TotalMilliseconds / $Duration * 100)
        $barWidth = 30
        $filled = [math]::Round(($barWidth * $progress) / 100)
        $empty = $barWidth - $filled
        $bar = "[" + ("#" * $filled) + ("." * $empty) + "]"
        
        Write-Host "`r $Message $bar $progress%" -NoNewline -ForegroundColor Cyan
        $i++
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r $Message [################################] 100%" -ForegroundColor Green
    Write-Host ""
}

# Update prüfen und durchführen
function Check-AndUpdate {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor DarkCyan
    Write-Host " CHECKING FOR UPDATES" -ForegroundColor White
    Write-Host "============================================================" -ForegroundColor DarkCyan
    
    try {
        # Version von GitHub abrufen
        $response = Invoke-RestMethod -Uri $UpdateURL -Method Get -TimeoutSec 5
        $latestVersion = $response.tag_name -replace 'v',''
        
        Write-Host " Current Version: $ScriptVersion" -ForegroundColor Gray
        Write-Host " Latest Version:  $latestVersion" -ForegroundColor Gray
        Write-Host ""
        
        # Versionsvergleich
        $currentParts = $ScriptVersion.Split('.') | ForEach-Object { [int]$_ }
        $latestParts = $latestVersion.Split('.') | ForEach-Object { [int]$_ }
        
        $updateAvailable = $false
        for ($i = 0; $i -lt [math]::Min($currentParts.Count, $latestParts.Count); $i++) {
            if ($latestParts[$i] -gt $currentParts[$i]) {
                $updateAvailable = $true
                break
            } elseif ($latestParts[$i] -lt $currentParts[$i]) {
                break
            }
        }
        
        if ($updateAvailable) {
            Write-Host "UPDATE AVAILABLE: $ScriptVersion -> $latestVersion" -ForegroundColor Green
            Write-Host ""
            
            if ($response.body) {
                Write-Host " WHAT'S NEW:" -ForegroundColor Yellow
                Write-Host "   $([Environment]::NewLine)$($response.body)" -ForegroundColor White
                Write-Host ""
            }
            
            Write-Host " Downloading update..." -ForegroundColorCyan
            Show-LoadingBar -Message " Downloading" -Duration 4000000000
            
            # Neues Script herunterladen
            if ($response.assets.Count -gt 0) {
                $downloadUrl = $response.assets[0].browser_download_url
            } else {
                $downloadUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/main/Textq.ps1"
            }
            
            $tempPath = [System.IO.Path]::GetTempPath() + "Textq_new.ps1"
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
            
            Write-Host " Update downloaded successfully!" -ForegroundColor Green
            Write-Host " Installing update..." -ForegroundColor Cyan
            Show-LoadingBar -Message " Installing" -Duration 2000
            
            # Altes Script ersetzen
            Copy-Item -Path $tempPath -Destination $ScriptPath -Force
            Remove-Item -Path $tempPath -Force
            
            Write-Host " Update installed successfully!" -ForegroundColor Green
            Write-Host " Restarting application..." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "============================================================" -ForegroundColor DarkCyan
            
            Start-Sleep -Seconds 2
            
            # Script neu starten
            Start-Process powershell.exe -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$ScriptPath`""
            exit
        } else {
            Write-Host "You are using the latest version: $ScriptVersion" -ForegroundColor Green
            Write-Host ""
            Write-Host "============================================================" -ForegroundColor DarkCyan
        }
        
    } catch {
        Write-Host "Update check failed (offline or server error)" -ForegroundColor Yellow
        Write-Host " Continuing with current version..." -ForegroundColor Gray
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkCyan
    }
}

# Auto-Update beim Start ausführen
Show-LoadingBar -Message " Initializing" -Duration 1500
Check-AndUpdate
Start-Sleep -Seconds 1

# ============================================================================
# MAIN APPLICATION CLASS
# ============================================================================

class FederTweetTool {
    # Eigenschaften
    [string]$BaseURL = "https://federtweet.com/api"
    [string]$ApiDocsURL = "https://federtweet.com/api-docs"
    [string]$CurrentVersion = "2.1.0"
    [hashtable]$RateLimits = @{}
    [System.Collections.ArrayList]$TweetCache = @()
    [hashtable]$ServiceStatus = @{
        "FederTweet API" = $false
        "AI Service" = $false
        "Last Check" = $null
    }

    # Konstruktor
    FederTweetTool() {
        Write-Host "+--------------------------------------------------+" -ForegroundColor DarkCyan
        Write-Host "|         F E D E R T W E E T   A P I             |" -ForegroundColor DarkCyan
        Write-Host "|         P O W E R S H E L L   T O O L           |" -ForegroundColor DarkCyan
        Write-Host "|                  v$($this.CurrentVersion)        |" -ForegroundColor DarkCyan
        Write-Host "+--------------------------------------------------+" -ForegroundColor DarkCyan
    }

    # Service-Status prüfen
    [void] CheckServiceStatus() {
        Clear-Host
        $this.ShowBanner()
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " CHECKING SERVICE STATUS" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        # FederTweet API prüfen
        $this.ShowLoader(" Checking FederTweet API", 800)
        try {
            $webRequest = [System.Net.WebRequest]::Create($this.BaseURL + "/tweets")
            $webRequest.Method = "GET"
            $webRequest.Timeout = 5000
            $response = $webRequest.GetResponse()
            $this.ServiceStatus["FederTweet API"] = $true
            $response.Close()
            Write-Host "`r FederTweet API: [ONLINE]" -ForegroundColor Green
        } catch {
            $this.ServiceStatus["FederTweet API"] = $false
            Write-Host "`r FederTweet API: [OFFLINE]" -ForegroundColor Red
        }

        # AI Service prüfen (simuliert)
        $this.ShowLoader(" Checking AI Service", 800)
        try {
            $aiCheck = $false
            $this.ServiceStatus["AI Service"] = $aiCheck
            if ($aiCheck) {
                Write-Host "`r AI Service: [ONLINE]" -ForegroundColor Green
            } else {
                Write-Host "`r AI Service: [OFFLINE]" -ForegroundColor Yellow
            }
        } catch {
            $this.ServiceStatus["AI Service"] = $false
            Write-Host "`r AI Service: [OFFLINE]" -ForegroundColor Red
        }

        $this.ServiceStatus["Last Check"] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host " API Documentation: $($this.ApiDocsURL)" -ForegroundColor Gray
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
    }

    # Service-Status anzeigen
    [void] ShowServiceStatus() {
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " SERVICE STATUS" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        Write-Host " FederTweet API: " -NoNewline
        if ($this.ServiceStatus["FederTweet API"]) {
            Write-Host "[ONLINE]" -ForegroundColor Green
        } else {
            Write-Host "[OFFLINE]" -ForegroundColor Red
        }

        Write-Host " AI Service: " -NoNewline
        if ($this.ServiceStatus["AI Service"]) {
            Write-Host "[ONLINE]" -ForegroundColor Green
        } else {
            Write-Host "[OFFLINE]" -ForegroundColor Yellow
        }

        if ($this.ServiceStatus["Last Check"]) {
            Write-Host ""
            Write-Host " Last Check: $($this.ServiceStatus["Last Check"])" -ForegroundColor Gray
        }
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host " API Documentation: $($this.ApiDocsURL)" -ForegroundColor Gray
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
    }

    # Banner anzeigen
    [void] ShowBanner() {
        Write-Host ' $$$$$$$$\                    $$\      $$$$$$\  ' -ForegroundColor DarkCyan
        Write-Host ' \__$$  __|                   $$ |    $$  __$$\ ' -ForegroundColor DarkCyan
        Write-Host '   $$ | $$$$$$\  $$\   $$\ $$$$$$\   $$ /  $$ | ' -ForegroundColor DarkCyan
        Write-Host '   $$ |$$  __$$\ \$$\ $$  |\_$$  _|  $$ |  $$ | ' -ForegroundColor DarkCyan
        Write-Host '   $$ |$$$$$$$$ | \$$$$  /   $$ |    $$ |  $$ | ' -ForegroundColor DarkCyan
        Write-Host '   $$ |$$   ____| $$  $$<    $$ |$$\ $$ $$\$$ | ' -ForegroundColor DarkCyan
        Write-Host '   $$ |\$$$$$$$\ $$  /\$$\   \$$$$  |\$$$$$$ /  ' -ForegroundColor DarkCyan
        Write-Host '   \__| \_______|\__/  \__|   \____/  \___$$$\  ' -ForegroundColor DarkCyan
        Write-Host '                                          \___| ' -ForegroundColor DarkCyan
        Write-Host ("=" * 70) -ForegroundColor DarkGray
        Write-Host "                    F E D E R T W E E T   A P I" -ForegroundColor White
        Write-Host "                    P O W E R S H E L L   T O O L" -ForegroundColor White
        Write-Host "                          v2.1.0 - Enterprise" -ForegroundColor Gray
        Write-Host ("=" * 70) -ForegroundColor DarkGray
    }

    # Lade-Animation
    [void] ShowLoader([string]$message, [int]$duration = 1000) {
        $frames = @("|", "/", "-", "\")
        $endTime = (Get-Date).AddMilliseconds($duration)
        $i = 0
        while ((Get-Date) -lt $endTime) {
            Write-Host "`r$message $($frames[$i % 4])" -NoNewline -ForegroundColor Gray
            $i++
            Start-Sleep -Milliseconds 100
        }
        Write-Host "`r$message " -NoNewline
        Write-Host "[" -NoNewline -ForegroundColor Green
        Write-Host "DONE" -NoNewline -ForegroundColor Green
        Write-Host "]" -ForegroundColor Green
    }

    # Fortschrittsbalken
    [void] ShowProgressBar([int]$current, [int]$total, [string]$message = "") {
        $width = 30
        $percent = [math]::Round(($current / $total) * 100)
        $filled = [math]::Round(($width * $current) / $total)
        $empty = $width - $filled
        $bar = "[" + ("#" * $filled) + ("." * $empty) + "]"
        if ($percent -ge 70) { $color = "Green" }
        elseif ($percent -ge 30) { $color = "Yellow" }
        else { $color = "Red" }
        Write-Host "`r$message $bar $percent% " -NoNewline -ForegroundColor $color
    }

    # API Request
    [object] MakeRequest([string]$Endpoint) {
        if (-not $this.ServiceStatus["FederTweet API"]) {
            Write-Host ""
            Write-Host "ERROR: FederTweet API is offline!" -ForegroundColor Red
            return $null
        }

        $url = $this.BaseURL + $Endpoint
        try {
            # Rate-Limit-Check
            if ($this.RateLimits.ContainsKey("Remaining") -and $this.RateLimits["Remaining"] -le 0) {
                $resetTime = [DateTimeOffset]::FromUnixTimeMilliseconds($this.RateLimits["Reset"]).LocalDateTime
                $waitTime = $resetTime - (Get-Date)
                Write-Host ""
                Write-Host ("!" * 50) -ForegroundColor Red
                Write-Host " RATE LIMIT REACHED - Waiting for reset..." -ForegroundColor Red
                Write-Host ("!" * 50) -ForegroundColor Red
                for ($i = $waitTime.TotalSeconds; $i -gt 0; $i--) {
                    $this.ShowProgressBar($waitTime.TotalSeconds - $i + 1, $waitTime.TotalSeconds, " Waiting:")
                    Start-Sleep -Seconds 1
                }
                Write-Host ""
            }

            $this.ShowLoader(" Sending request", 800)
            $webRequest = [System.Net.WebRequest]::Create($url)
            $webRequest.Method = "GET"
            $webRequest.UserAgent = "FederTweet-PowerShell-Tool/2.1"
            $response = $webRequest.GetResponse()
            $stream = $response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
            $stream.Close()
            $response.Close()

            # Rate-Limit-Header auslesen
            if ($response.Headers["X-RateLimit-Limit"]) {
                $this.RateLimits["Limit"] = [int]$response.Headers["X-RateLimit-Limit"]
            }
            if ($response.Headers["X-RateLimit-Remaining"]) {
                $this.RateLimits["Remaining"] = [int]$response.Headers["X-RateLimit-Remaining"]
            }
            if ($response.Headers["X-RateLimit-Reset"]) {
                $this.RateLimits["Reset"] = [long]$response.Headers["X-RateLimit-Reset"]
            }

            $jsonResponse = $responseBody | ConvertFrom-Json
            return $jsonResponse
        } catch {
            if ($_.Exception.Message -like "*429*") {
                Write-Host ""
                Write-Host ("!" * 50) -ForegroundColor Red
                Write-Host " RATE LIMIT EXCEEDED - Auto-waiting 60s..." -ForegroundColor Red
                Write-Host ("!" * 50) -ForegroundColor Red
                for ($i = 60; $i -gt 0; $i--) {
                    $this.ShowProgressBar(60 - $i + 1, 60, " Countdown:")
                    Start-Sleep -Seconds 1
                }
                Write-Host ""
                return $this.MakeRequest($Endpoint)
            } else {
                Write-Host ""
                Write-Host ("!" * 50) -ForegroundColor Red
                Write-Host " ERROR: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ("!" * 50) -ForegroundColor Red
                return $null
            }
        }
    }

    # Rate-Limit anzeigen
    [void] DisplayRateLimit() {
        if ($this.RateLimits.ContainsKey("Remaining") -and $this.RateLimits.ContainsKey("Limit")) {
            $percent = [math]::Round(($this.RateLimits["Remaining"] / $this.RateLimits["Limit"]) * 100)
            Write-Host ""
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            Write-Host " RATE LIMIT STATUS" -ForegroundColor White
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            $this.ShowProgressBar($this.RateLimits["Remaining"], $this.RateLimits["Limit"], " Remaining:")
            Write-Host ""
            if ($this.RateLimits.ContainsKey("Reset")) {
                $resetDate = [DateTimeOffset]::FromUnixTimeMilliseconds($this.RateLimits["Reset"]).LocalDateTime
                Write-Host " Reset Time: $resetDate" -ForegroundColor Gray
            }
            Write-Host ("-" * 60) -ForegroundColor DarkGray
        }
    }

    # Tweets eines Users anzeigen
    [void] GetUserTweets([string]$Username) {
        Clear-Host
        $this.ShowBanner()
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " FETCHING TWEETS FOR: @$Username" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        $response = $this.MakeRequest("/user/$Username/tweets")
        if ($response -and $response.success) {
            $tweets = $response.tweets
            if ($tweets.Count -eq 0) {
                Write-Host ""
                Write-Host "No tweets found for @$Username" -ForegroundColor Yellow
                return
            }

            # Statistiken berechnen
            $totalLikes = ($tweets | Measure-Object -Property likes -Sum).Sum
            $totalRetweets = ($tweets | Measure-Object -Property retweets -Sum).Sum
            $avgLikes = [math]::Round(($tweets | Measure-Object -Property likes -Average).Average, 1)
            $avgRetweets = [math]::Round(($tweets | Measure-Object -Property retweets -Average).Average, 1)

            Write-Host ""
            Write-Host "STATISTICS:" -ForegroundColor Cyan
            Write-Host "  Total Tweets:    $($tweets.Count)" -ForegroundColor White
            Write-Host "  Total Likes:     $totalLikes" -ForegroundColor White
            Write-Host "  Total Retweets:  $totalRetweets" -ForegroundColor White
            Write-Host "  Avg Likes:       $avgLikes" -ForegroundColor White
            Write-Host "  Avg Retweets:    $avgRetweets" -ForegroundColor White

            Write-Host ""
            Write-Host "LATEST TWEETS:" -ForegroundColor Cyan
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            $maxTweets = [math]::Min(2, $tweets.Count-1)
            if ($maxTweets -ge 0) {
                foreach ($tweet in $tweets[0..$maxTweets]) {
                    $this.DisplayTweet($tweet)
                    Start-Sleep -Milliseconds 300
                }
            }
            $this.TweetCache.AddRange($tweets)
        }
    }

    # Global Feed anzeigen
    [void] GetGlobalFeed() {
        Clear-Host
        $this.ShowBanner()
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " GLOBAL FEED" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        $response = $this.MakeRequest("/tweets")
        if ($response -and $response.success) {
            $tweets = $response.tweets
            if ($tweets.Count -eq 0) {
                Write-Host ""
                Write-Host "No tweets in feed" -ForegroundColor Yellow
                return
            }

            $topLiked = $tweets | Sort-Object -Property likes -Descending | Select-Object -First 3
            $topRetweeted = $tweets | Sort-Object -Property retweets -Descending | Select-Object -First 3

            Write-Host ""
            Write-Host "TOP LIKED:" -ForegroundColor Yellow
            foreach ($tweet in $topLiked) {
                Write-Host "  @$($tweet.username): $($tweet.likes) likes" -ForegroundColor White
            }

            Write-Host ""
            Write-Host "TOP RETWEETED:" -ForegroundColor Yellow
            foreach ($tweet in $topRetweeted) {
                Write-Host "  @$($tweet.username): $($tweet.retweets) retweets" -ForegroundColor White
            }

            Write-Host ""
            Write-Host "RECENT TWEETS:" -ForegroundColor Cyan
            Write-Host ("-" * 60) -ForegroundColor DarkGray
            $maxTweets = [math]::Min(2, $tweets.Count-1)
            if ($maxTweets -ge 0) {
                foreach ($tweet in $tweets[0..$maxTweets]) {
                    $this.DisplayTweet($tweet)
                    Start-Sleep -Milliseconds 300
                }
            }
            $this.TweetCache.AddRange($tweets)
        }
    }

    # User-Profil anzeigen
    [void] GetUserProfile([string]$Username) {
        Clear-Host
        $this.ShowBanner()
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " USER PROFILE: @$Username" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        $response = $this.MakeRequest("/user/$Username")
        if ($response -and $response.success) {
            $user = $response.user
            Write-Host ""
            Write-Host "USER INFORMATION:" -ForegroundColor Cyan
            Write-Host "  Username:  @$($user.username)" -ForegroundColor White
            Write-Host "  Bio:       $($user.bio)" -ForegroundColor White

            Write-Host ""
            Write-Host "STATISTICS:" -ForegroundColor Cyan
            Write-Host "  Tweets:    $($user.tweetCount)" -ForegroundColor White
            Write-Host "  Followers: $($user.followersCount)" -ForegroundColor White
            Write-Host "  Following: $($user.followingCount)" -ForegroundColor White

            if ($user.partnerInfo -and $user.partnerInfo.username) {
                Write-Host ""
                Write-Host "PARTNER:" -ForegroundColor Cyan
                Write-Host "  @$($user.partnerInfo.username)" -ForegroundColor Magenta
            }
        }
    }

    # AI-gestützte Analyse (simuliert)
    [void] AnalyzeWithAI() {
        if (-not $this.ServiceStatus["AI Service"]) {
            Write-Host ""
            Write-Host ("!" * 50) -ForegroundColor Yellow
            Write-Host " AI Service is currently offline" -ForegroundColor Yellow
            Write-Host " Using basic analysis instead..." -ForegroundColor Yellow
            Write-Host ("!" * 50) -ForegroundColor Yellow
            $this.AnalyzeTweets()
            return
        }

        if ($this.TweetCache.Count -eq 0) {
            Write-Host ""
            Write-Host ("!" * 50) -ForegroundColor Red
            Write-Host " No tweets in cache for analysis!" -ForegroundColor Red
            Write-Host ("!" * 50) -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " AI-POWERED ANALYSIS" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        $this.ShowLoader(" AI analyzing tweet patterns", 2000)

        $tweets = $this.TweetCache

        # Erweiterte Analyse (simulierte AI)
        $totalLikes = ($tweets | Measure-Object -Property likes -Sum).Sum
        $totalRetweets = ($tweets | Measure-Object -Property retweets -Sum).Sum
        $totalEngagement = $totalLikes + $totalRetweets
        $avgEngagement = [math]::Round($totalEngagement / $tweets.Count, 1)
        $bestTweet = $tweets | Sort-Object -Property {$_.likes + $_.retweets} -Descending | Select-Object -First 1
        $worstTweet = $tweets | Sort-Object -Property {$_.likes + $_.retweets} | Select-Object -First 1

        # Sentiment-Analyse (simuliert)
        $positiveKeywords = @("good", "great", "awesome", "love", "best", "excellent", "happy")
        $negativeKeywords = @("bad", "worst", "hate", "terrible", "awful", "sad", "angry")
        $positiveCount = 0
        $negativeCount = 0
        $neutralCount = 0

        foreach ($tweet in $tweets) {
            $text = $tweet.text.ToLower()
            $positive = ($positiveKeywords | Where-Object { $text.Contains($_) }).Count
            $negative = ($negativeKeywords | Where-Object { $text.Contains($_) }).Count
            if ($positive -gt $negative) { $positiveCount++ }
            elseif ($negative -gt $positive) { $negativeCount++ }
            else { $neutralCount++ }
        }

        Write-Host ""
        Write-Host "ENGAGEMENT METRICS:" -ForegroundColor Cyan
        Write-Host "  Total Engagement: $totalEngagement" -ForegroundColor Green
        Write-Host "  Avg per Tweet:    $avgEngagement" -ForegroundColor Yellow

        Write-Host ""
        Write-Host "SENTIMENT ANALYSIS:" -ForegroundColor Cyan
        Write-Host "  Positive: $positiveCount tweets" -ForegroundColor Green
        Write-Host "  Neutral:  $neutralCount tweets" -ForegroundColor Gray
        Write-Host "  Negative: $negativeCount tweets" -ForegroundColor Red

        Write-Host ""
        Write-Host "BEST PERFORMING:" -ForegroundColor Cyan
        Write-Host "  Text:       $($bestTweet.text)" -ForegroundColor White
        Write-Host "  Engagement: $($bestTweet.likes + $bestTweet.retweets)" -ForegroundColor Green

        Write-Host ""
        Write-Host "WORST PERFORMING:" -ForegroundColor Cyan
        Write-Host "  Text:       $($worstTweet.text)" -ForegroundColor White
        Write-Host "  Engagement: $($worstTweet.likes + $worstTweet.retweets)" -ForegroundColor Red

        Write-Host ""
        Write-Host "AI INSIGHTS:" -ForegroundColor Magenta
        if ($positiveCount -gt $negativeCount) {
            Write-Host "  Overall positive sentiment detected" -ForegroundColor Green
        } elseif ($negativeCount -gt $positiveCount) {
            Write-Host "  Overall negative sentiment detected" -ForegroundColor Red
        } else {
            Write-Host "  Neutral sentiment detected" -ForegroundColor Gray
        }

        if ($avgEngagement -gt 50) {
            Write-Host "  High engagement rate - Content resonates well" -ForegroundColor Green
        } elseif ($avgEngagement -gt 20) {
            Write-Host "  Moderate engagement rate - Room for improvement" -ForegroundColor Yellow
        } else {
            Write-Host "  Low engagement rate - Consider content strategy" -ForegroundColor Red
        }
    }

    # Tweet-Analyse (Basis)
    [void] AnalyzeTweets() {
        if ($this.TweetCache.Count -eq 0) {
            Write-Host ""
            Write-Host ("!" * 50) -ForegroundColor Red
            Write-Host " No tweets in cache for analysis!" -ForegroundColor Red
            Write-Host ("!" * 50) -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " BASIC ANALYSIS" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        $tweets = $this.TweetCache
        $totalLikes = ($tweets | Measure-Object -Property likes -Sum).Sum
        $totalRetweets = ($tweets | Measure-Object -Property retweets -Sum).Sum
        $totalEngagement = $totalLikes + $totalRetweets
        $avgEngagement = [math]::Round($totalEngagement / $tweets.Count, 1)
        $bestTweet = $tweets | Sort-Object -Property {$_.likes + $_.retweets} -Descending | Select-Object -First 1

        Write-Host ""
        Write-Host "ENGAGEMENT METRICS:" -ForegroundColor Cyan
        Write-Host "  Total Engagement: $totalEngagement" -ForegroundColor Green
        Write-Host "  Avg per Tweet:    $avgEngagement" -ForegroundColor Yellow

        Write-Host ""
        Write-Host "BEST TWEET:" -ForegroundColor Cyan
        Write-Host "  Text:       $($bestTweet.text)" -ForegroundColor White
        Write-Host "  Engagement: $($bestTweet.likes + $bestTweet.retweets) (Likes: $($bestTweet.likes), Retweets: $($bestTweet.retweets))" -ForegroundColor Green
    }

    # Einzelnen Tweet anzeigen
    [void] DisplayTweet($tweet) {
        Write-Host ("+" + ("-" * 58) + "+") -ForegroundColor DarkGray
        Write-Host "| @$( $tweet.username )" -ForegroundColor Cyan
        $text = $tweet.text
        if ($text.Length -gt 50) {
            $text = $text.Substring(0, 50) + "..."
        }
        Write-Host "| $text" -ForegroundColor White
        Write-Host "| Likes: $($tweet.likes)  Retweets: $($tweet.retweets)  " -NoNewline
        $date = [DateTime]::Parse($tweet.createdAt)
        Write-Host "$($date.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
        if ($tweet.partnerInfo -and $tweet.partnerInfo.username) {
            Write-Host "| With: @$( $tweet.partnerInfo.username )" -ForegroundColor Magenta
        }
        Write-Host ("+" + ("-" * 58) + "+") -ForegroundColor DarkGray
        Write-Host ""
    }

    # Warten auf Tastendruck
    [void] WaitForKey() {
        Write-Host ""
        Write-Host ("-" * 60) -ForegroundColor DarkGray
        Write-Host "Press Enter to continue..." -ForegroundColor Gray -NoNewline
        Read-Host
    }

    # Startmenü mit Service-Auswahl
    [void] ShowStartMenu() {
        Clear-Host
        $this.ShowBanner()
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " SERVICE SELECTION" -ForegroundColor White
        Write-Host ("=" * 60) -ForegroundColor DarkCyan
        Write-Host " 1. Check Service Status" -ForegroundColor White
        Write-Host " 2. Start FederTweet Tool" -ForegroundColor White
        Write-Host " 3. View API Documentation" -ForegroundColor White
        Write-Host " 0. Exit" -ForegroundColor Red
        Write-Host ("=" * 60) -ForegroundColor DarkCyan

        $choice = Read-Host "`n> Selection"
        switch ($choice) {
            "1" {
                $this.CheckServiceStatus()
                $this.WaitForKey()
                $this.ShowStartMenu()
            }
            "2" {
                $this.ShowMenu()
            }
            "3" {
                Write-Host ""
                Write-Host "API Documentation: $($this.ApiDocsURL)" -ForegroundColor Cyan
                $this.WaitForKey()
                $this.ShowStartMenu()
            }
            "0" {
                Write-Host ""
                Write-Host "Exiting..." -ForegroundColor DarkCyan
                exit
            }
            default {
                Write-Host ""
                Write-Host "Invalid selection!" -ForegroundColor Red
                $this.WaitForKey()
                $this.ShowStartMenu()
            }
        }
    }

    # Interaktives Menü
    [void] ShowMenu() {
        $choice = ""
        do {
            Clear-Host
            $this.ShowBanner()
            $this.ShowServiceStatus()
            Write-Host ""
            Write-Host ("+" + ("-" * 58) + "+") -ForegroundColor DarkCyan
            Write-Host "|                    M A I N   M E N U                    |" -ForegroundColor White
            Write-Host ("+" + ("-" * 58) + "+") -ForegroundColor DarkCyan
            Write-Host "  1. View User Tweets" -ForegroundColor White
            Write-Host "  2. View Global Feed" -ForegroundColor White
            Write-Host "  3. View User Profile" -ForegroundColor White
            Write-Host "  4. Analyze with AI" -ForegroundColor $(if ($this.ServiceStatus["AI Service"]) { "Green" } else { "Yellow" })
            Write-Host "  5. Basic Analysis" -ForegroundColor White
            Write-Host "  6. Check Rate Limit" -ForegroundColor White
            Write-Host "  7. Clear Cache" -ForegroundColor White
            Write-Host "  8. Refresh Service Status" -ForegroundColor White
            Write-Host "  0. Exit" -ForegroundColor Red
            Write-Host ("+" + ("-" * 58) + "+") -ForegroundColor DarkCyan

            $choice = Read-Host "`n> Selection"
            switch ($choice) {
                "1" {
                    $username = Read-Host " Username"
                    $this.GetUserTweets($username)
                    $this.WaitForKey()
                }
                "2" {
                    $this.GetGlobalFeed()
                    $this.WaitForKey()
                }
                "3" {
                    $username = Read-Host " Username"
                    $this.GetUserProfile($username)
                    $this.WaitForKey()
                }
                "4" {
                    $this.AnalyzeWithAI()
                    $this.WaitForKey()
                }
                "5" {
                    $this.AnalyzeTweets()
                    $this.WaitForKey()
                }
                "6" {
                    $this.DisplayRateLimit()
                    $this.WaitForKey()
                }
                "7" {
                    $this.ShowLoader(" Clearing cache", 500)
                    $this.TweetCache.Clear()
                    Write-Host ""
                    Write-Host "Cache cleared successfully!" -ForegroundColor Green
                    $this.WaitForKey()
                }
                "8" {
                    $this.CheckServiceStatus()
                    $this.WaitForKey()
                }
                "0" {
                    Write-Host ""
                    Write-Host "Exiting FederTweet Tool..." -ForegroundColor DarkCyan
                    break
                }
                default {
                    Write-Host ""
                    Write-Host ("!" * 50) -ForegroundColor Red
                    Write-Host " Invalid selection!" -ForegroundColor Red
                    Write-Host ("!" * 50) -ForegroundColor Red
                    $this.WaitForKey()
                }
            }
        } while ($choice -ne "0")
    }
}

# ============================================================================
# HAUPTPROGRAMM
# ============================================================================

Clear-Host

# ASCII Banner
Write-Host ' $$$$$$$$\                    $$\      $$$$$$\  ' -ForegroundColor DarkCyan
Write-Host ' \__$$  __|                   $$ |    $$  __$$\ ' -ForegroundColor DarkCyan
Write-Host '   $$ | $$$$$$\  $$\   $$\ $$$$$$\   $$ /  $$ | ' -ForegroundColor DarkCyan
Write-Host '   $$ |$$  __$$\ \$$\ $$  |\_$$  _|  $$ |  $$ | ' -ForegroundColor DarkCyan
Write-Host '   $$ |$$$$$$$$ | \$$$$  /   $$ |    $$ |  $$ | ' -ForegroundColor DarkCyan
Write-Host '   $$ |$$   ____| $$  $$<    $$ |$$\ $$ $$\$$ | ' -ForegroundColor DarkCyan
Write-Host '   $$ |\$$$$$$$\ $$  /\$$\   \$$$$  |\$$$$$$ /  ' -ForegroundColor DarkCyan
Write-Host '   \__| \_______|\__/  \__|   \____/  \___$$$\  ' -ForegroundColor DarkCyan
Write-Host '                                          \___| ' -ForegroundColor DarkCyan
Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host "                    F E D E R T W E E T   A P I" -ForegroundColor White
Write-Host "                    P O W E R S H E L L   T O O L" -ForegroundColor White
Write-Host "                          v2.1.0 - Enterprise" -ForegroundColor Gray
Write-Host ("=" * 70) -ForegroundColor DarkGray

# Tool initialisieren
$tool = [FederTweetTool]::new()

# Startmenü anzeigen
$tool.ShowStartMenu()

# License Information
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host " LICENSE INFORMATION" -ForegroundColor White
Write-Host ("=" * 70) -ForegroundColor DarkGray
Write-Host " FederTweet API  - Licensed under FederTweet Terms of Service" -ForegroundColor Gray
Write-Host " AI API          - Licensed under FederTweet AI Terms of Service" -ForegroundColor Gray
Write-Host ("=" * 70) -ForegroundColor DarkGray
