param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubToken,

    [Parameter(Mandatory=$true)]
    [string]$Organization,

    [Parameter(Mandatory=$true)]
    [string]$Repository,

    [string]$OutputFolder = ".\Reports"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$headers = @{
    Authorization = "Bearer $GitHubToken"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent" = "PowerShell-GitHub-Security-Scanner"
}

function Invoke-GitHubPagedRequest {
    param([string]$Uri)

    $results = @()
    while ($Uri) {
        Write-Host "GET $Uri" -ForegroundColor Cyan

        $response = Invoke-WebRequest -Uri $Uri -Headers $headers -Method Get

        if ($response.Content) {
            $data = $response.Content | ConvertFrom-Json
            if ($data -is [System.Array]) {
                $results += $data
            } else {
                $results += ,$data
            }
        }

        $Uri = $null
        $link = $response.Headers["Link"]
        if ($link -and $link -match '<([^>]+)>;\s*rel="next"') {
            $Uri = $matches[1]
        }
    }

    return $results
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host " GitHub Dependabot Security Scanner"
Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "Organization : $Organization"
Write-Host "Repository   : $Repository"
Write-Host ""

$api = "https://api.github.com/repos/$Organization/$Repository/dependabot/alerts?state=open&per_page=100"

try {
    $alerts = Invoke-GitHubPagedRequest -Uri $api

    if (!$alerts -or $alerts.Count -eq 0) {
        Write-Host "No open Dependabot alerts found." -ForegroundColor Green
        exit 0
    }

    $report = foreach ($a in $alerts) {
        [PSCustomObject]@{
            Repository = "$Organization/$Repository"
            Severity   = $a.security_advisory.severity
            Package    = $a.dependency.package.name
            Ecosystem  = $a.dependency.package.ecosystem
            Summary    = $a.security_advisory.summary
            CVE        = ($a.security_advisory.cve_id)
            GHSA       = ($a.security_advisory.ghsa_id)
            State      = $a.state
            CreatedAt  = $a.created_at
            URL        = $a.html_url
        }
    }

    Write-Host ""
    Write-Host "========= SUMMARY =========" -ForegroundColor Yellow

    foreach ($sev in "critical","high","medium","low") {
        $count = ($report | Where-Object {$_.Severity -eq $sev}).Count
        Write-Host ("{0,-10}: {1}" -f $sev.ToUpper(),$count)
    }

    Write-Host ""
    Write-Host "========= ALERTS =========" -ForegroundColor Yellow
    $report | Format-Table Severity,Package,CVE,State -AutoSize

    $csv = Join-Path $OutputFolder "DependabotAlerts.csv"
    $json = Join-Path $OutputFolder "DependabotAlerts.json"

    $report | Export-Csv $csv -NoTypeInformation
    $report | ConvertTo-Json -Depth 10 | Out-File $json -Encoding utf8

    Write-Host ""
    Write-Host "CSV  : $csv" -ForegroundColor Green
    Write-Host "JSON : $json" -ForegroundColor Green

    if (($report | Where-Object Severity -eq "critical").Count -gt 0) {
        Write-Warning "Critical vulnerabilities detected."
        exit 2
    }
}
catch {
    Write-Error $_
    exit 1
}
