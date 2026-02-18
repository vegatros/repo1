#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tag AWS resources with specified tags.

.DESCRIPTION
    This script tags AWS resources (EC2, S3, RDS, etc.) with custom tags.
    Can tag individual resources or bulk tag from a CSV file.

.PARAMETER ResourceIds
    Array of AWS resource IDs to tag

.PARAMETER Tags
    Hashtable of tags to apply (Key-Value pairs)

.PARAMETER CsvFile
    Path to CSV file with columns: ResourceId, and tag columns

.PARAMETER Region
    AWS region (default: us-east-1)

.EXAMPLE
    .\Tag-AwsResources.ps1 -ResourceIds @("i-1234567890abcdef0") -Tags @{Environment="dev"; Owner="admin"}

.EXAMPLE
    .\Tag-AwsResources.ps1 -CsvFile "resources.csv" -Region "us-east-1"
#>

param(
    [Parameter(Mandatory=$false)]
    [string[]]$ResourceIds,
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Tags,
    
    [Parameter(Mandatory=$false)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

function Tag-Resource {
    param($ResourceId, $TagHash)
    
    $tagArgs = @()
    foreach ($key in $TagHash.Keys) {
        $tagArgs += "Key=$key,Value=$($TagHash[$key])"
    }
    
    try {
        Write-Host "Tagging resource: $ResourceId" -ForegroundColor Green
        
        $result = aws ec2 create-tags `
            --resources $ResourceId `
            --tags $tagArgs `
            --region $Region 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Successfully tagged: $ResourceId" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Failed to tag: $ResourceId - $result" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ Error tagging $ResourceId : $_" -ForegroundColor Red
    }
}

# Process CSV file
if ($CsvFile) {
    if (-not (Test-Path $CsvFile)) {
        Write-Host "Error: CSV file not found: $CsvFile" -ForegroundColor Red
        exit 1
    }
    
    $resources = Import-Csv $CsvFile
    
    foreach ($resource in $resources) {
        $resourceId = $resource.ResourceId
        
        # Extract tags from CSV columns (exclude ResourceId column)
        $csvTags = @{}
        $resource.PSObject.Properties | Where-Object { $_.Name -ne "ResourceId" } | ForEach-Object {
            if ($_.Value) {
                $csvTags[$_.Name] = $_.Value
            }
        }
        
        Tag-Resource -ResourceId $resourceId -TagHash $csvTags
    }
}
# Process individual resources
elseif ($ResourceIds -and $Tags) {
    foreach ($resourceId in $ResourceIds) {
        Tag-Resource -ResourceId $resourceId -TagHash $Tags
    }
}
else {
    Write-Host "Error: Provide either -CsvFile or both -ResourceIds and -Tags" -ForegroundColor Red
    exit 1
}

Write-Host "`nTagging complete!" -ForegroundColor Cyan
