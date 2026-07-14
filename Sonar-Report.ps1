# ===========================
# Configuration
# ===========================
$organization = "DevOps-Rx"
$project = "Basket-Insightz"      # Change this for each project
$pat = "79vpicSk5INu7G2WBw8uaZlcpJds3Ay4HjQahA9618cU3E57OvFXJQQJ99CGACAAAAAIBO3XAAASAZDO1K1B"

# ===========================
# Authentication
# ===========================
$base64AuthInfo = [Convert]::ToBase64String(
    [Text.Encoding]::ASCII.GetBytes(":$pat")
)

$headers = @{
    Authorization = "Basic $base64AuthInfo"
}

# ===========================
# Get Pipelines
# ===========================
$url = "https://dev.azure.com/$organization/$project/_apis/pipelines?api-version=7.1-preview.1"

$response = Invoke-RestMethod `
    -Uri $url `
    -Headers $headers `
    -Method Get

# ===========================
# Build Report
# ===========================
$result = foreach ($pipeline in $response.value)
{
    [PSCustomObject]@{
        Project      = $project
        PipelineName = $pipeline.name
        PipelineId   = $pipeline.id
        Folder       = $pipeline.folder
        Url          = $pipeline.url
    }
}

# Display
$result | Format-Table -AutoSize

# Export
$result | Export-Csv "Pipelines_$project.csv" -NoTypeInformation

Write-Host ""
Write-Host "CSV exported to Pipelines_$project.csv"


