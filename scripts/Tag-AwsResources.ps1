#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tag AWS resources with specified tags.

.DESCRIPTION
    This script tags AWS resources (EC2, S3, RDS, etc.) with custom tags.

.PARAMETER ResourceIds
    Array of AWS resource IDs to tag

.PARAMETER Tags
    Hashtable of tags to apply (Key-Value pairs)

.PARAMETER Region
    AWS region (default: us-east-1)

.EXAMPLE
    .\Tag-AwsResources.ps1 -ResourceIds @("i-1234567890abcdef0") -Tags @{Environment="dev"; Owner="admin"}
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$ResourceIds,
    
    [Parameter(Mandatory=$true)]
    [hashtable]$Tags,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-east-1"
)

# Convert hashtable to AWS tag format
$awsTags = @()
foreach ($key in $Tags.Keys) {
    $awsTags += @{
        Key = $key
        Value = $Tags[$key]
    }
}

# Tag resources
foreach ($resourceId in $ResourceIds) {
    try {
        Write-Host "Tagging resource: $resourceId" -ForegroundColor Green
        
        aws ec2 create-tags `
            --resources $resourceId `
            --tags $(($awsTags | ForEach-Object { "Key=$($_.Key),Value=$($_.Value)" }) -join " ") `
            --region $Region
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Successfully tagged: $resourceId" -ForegroundColor Green
        } else {
            Write-Host "Failed to tag: $resourceId" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error tagging $resourceId : $_" -ForegroundColor Red
    }
}

Write-Host "`nTagging complete!" -ForegroundColor Cyan
