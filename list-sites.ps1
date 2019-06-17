# gschneider-r7 (GitHub)
# ref - https://github.com/rapid7/nexpose-resources/blob/master/scripts/sites/list_sites/powershell/list_sites.ps1

#_2
# Use a rest api call with base 64 encoded credentials 
# ref - https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

#_3
# INSIGHTVM API (V3)
# https://itc9001.amer.int.tenneco.com:3780/api/3/html

# Create a connection to a Nexpose console server, and build a listing of sites.


# Define Global Variables ...
$pageSize = 10
$siteList = [PsCustomObject[]]@(0)
$operation = 'Get'
$context = 'sites'


# Define a connection credential and encode it for the REST API call ...
$psCreds = Get-Credential
$credPair= $psCreds.UserName.ToString() + ":" + $psCreds.GetNetworkCredential().password
$endcodedCredPair = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))


# Define the connection values
### $server = '[SERVER NAME HERE]' <== Unremark and add the hostname/IP address for the Nexpose console server.

$port = '3780'
$headers = @{ Authorization = "Basic $endcodedCredPair" }


# Define functions

function Get-Sites([PSCustomObject]$resp) {

        $List = [PsCustomObject[]]@()
        $totalPages = $resp.page.totalPages
        $totalResources = $resp.page.totalResources
        $progress = 0

        # Contacting the server and read the Nexpose responses...
        For ($pageNum=0; $pageNum -lt $totalPages; $pageNum++) {

 
            $uri = "https://${server}:${port}/api/3/$context/?page=$pageNum&size=$size" 
            $resourcesResp = Invoke-RestMethod -URI $uri -Headers $headers -ContentType 'application/json' -Method $operation
            $resourceList = @(0) * $resourcesResp.resources.Length 
       
            # For each site in the returned Page ...
            For ($i=0; $i -lt $resourceList.Length; $i++) {

                # Populate an object with the returned Resources ...
                $resource= [PSCustomObject]@{
                    ID = $resourcesResp.resources[$i].id
                    name = $resourcesResp.resources[$i].name
                    description = $resourcesResp.resources[$i].description
                    lastScanTime = $resourcesResp.resources[$i].lastScanTime
                    riskScore = $resourcesResp.resources[$i].riskScore
                    scanEngine = $resourcesResp.resources[$i].scanEngine
                    importance = $resourcesResp.resources[$i].importance
                    scanTemplate = $resourcesResp.resources[$i].scanTemplate
                }
        
            
            # Then get the Included Target Values for each Resource
            $ID = $resource.ID
            $uri = "https://${server}:${port}/api/3/$context/$ID/included_targets"       
            $inclTargetsResp = Invoke-RestMethod -URI $uri -Headers $headers -ContentType 'application/json' -Method $operation 
          
            $targets = [String]$inclTargetsResp.addresses
            $resource | Add-Member -MemberType NoteProperty -Name addresses -Value $targets


            # Then add the site object into an array ...
            $List += $resource 
            $resource = $null

            Write-Progress -Activity "Reading Nexpose responses for $progress of $totalResources total sites..." -Status 'Progress' -PercentComplete (($progress/$totalResources)*100)
            $progress++

            }
        }

        # Return a list of Sites ...
        Write-Host "`nHere is a listing of Sites from Nexpose: "
        return $List

}

function Get-CSV {

    do {

        try {

            $inputOK = $true
            $csv = Read-Host - Prompt "Please provide a path and filename ..."

        } catch { $inputOK = $false }

    } until (($csv -notmatch "^[\\\/\:\*\?\<\>\|]*$") -and $inputOK)

    return $csv
}


# Ask for a file to store the results ...

$outputFile = Get-CSV


# Try to make a call to the REST API, and then process the response ...
try {
    
    # Make the Nexpose connection, and determine how much information we need to pull back ...

    $uri = "https://${server}:${port}/api/3/$context"
    $resp = Invoke-RestMethod -URI $uri -Headers $headers -ContentType 'application/json' -Method $operation
    $siteList = Get-Sites($resp)

    $siteList | Format-Table 
    $siteList | Export-CSV -NoTypeInformation -Path $outputFile 


} catch { 

    $err=$_.Exception
    Write-Host "`n$err.Response`n" -ForegroundColor red
}


