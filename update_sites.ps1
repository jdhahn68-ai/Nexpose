# gschneider-r7 (GitHub)
# ref - https://github.com/rapid7/nexpose-resources/blob/master/scripts/sites/list_sites/powershell/list_sites.ps1

#_2
# Use a rest api call with base 64 encoded credentials 
# ref - https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

#_3
# INSIGHTVM API (V3)
# https://itc9001.amer.int.tenneco.com:3780/api/3/html#operation/updateIncludedTargets

#_4
# The Nexpose API requires an array of string as input.
# http://grr.blahnet.com/powershell/convert-cast-object-array-to-string-array



# This script is designed to read from subnet-inventory file:
<#
    Each site may hold multiple CIDR blocks, and therefore each site may be listed in one or more rows.
    The CSV input file must contain the following column headings:   

    siteCode	CIDR siteID	 scanEngineId	importance	 scanTemplateId 
    ========    ==== ======  ============   ==========   ==============

    It uses a hash table to hold the site listing in memory, then executes a Nexpose REST API to update
    Nexpose one site at a time.

#>

                                                                                     
# Define Global Variables ..
$operation = "Put"
$resource = "sites"
$messageBody = @{}
$included_targets = [String[]]@()
$siteUpdateList = @{}



# Define a connection credential and encode it for the REST API call ...
$psCreds = Get-Credential
$credPair= $psCreds.UserName.ToString() + ":" + $psCreds.GetNetworkCredential().password
$endcodedCredPair = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($credPair))



# Define the connection values
### $server = '[SERVER NAME HERE]' <== Unremark and add the hostname/IP address for the Nexpose console server.

$port = '3780'
$headers = @{ Authorization = "Basic $endcodedCredPair" }



# Define functions
function Get-CSV {

    do {

        try {

            $inputOK = $true
            $path = Read-Host - Prompt "Please provide a path and filename ..."

        } catch { $inputOK = $false }

    } until (($path -notmatch "^[\/\:\*\?\<\>\|]*$") -and $inputOK)
 
    $csv = Import-Csv -Path $path
    return $csv   
}


function Get-Site-Updates([PSCustomObject]$inObjectList) {
    
    $List = [ordered] @{}

    # Read the infile and build a list of sites ...
    $inObjectList |  ForEach-Object {

        $ID = $_.siteID
        $site = $null

        # The infile will contain sites that have multiple entries. 
        # I.e.: Each site ID is assigned one or more subnet (CIDR ranges).
        # We therefore need to create a record, and for each CIDR add additional subnets
        #
        if (!$List.Contains($ID)) {
    
            # Create a site object if we've not yet encountered a row with this site ID ...
            $site = [PSCustomObject]@{
                name = $_.siteCode
                scanTemplateId = $_.scanTemplateId
                engineId = $_.scanEngineId
                importance = $_.importance
                addresses = [String[]]@($_.cidr)
            }

            # Then add this created site object to our list of updates ...
            $List.Add($ID,$site)

        } else {
           
            # Or else update the existing site object with additional subnets ...
            $List.$ID.Addresses += [String]$_.cidr  
        }         
    }
    return $List
 }




# Read the subnet-inventory file and create a list of updates
$subnetInventory = Get-CSV
$siteUpdateList = Get-Site-Updates($subnetInventory)


# Then update Nexpose sites ...
$siteUpdateList.GetEnumerator() | % {


   # Update existing sites.
   # A site is new to Nexpose (i.e. it must be added, not updated) if the subnet-inventory ID value is 0
   if ($($_.key) -ne 0) {

        try {

            $siteID = $_.Key

            # Update the site information ...
            $messageBody = $_.Value
            $messageBody | ConvertTo-Json
            $uri = "https://${server}:${port}/api/3/$resource/$siteID" 
            $resp = Invoke-RestMethod -URI $uri -Headers $headers -ContentType 'application/json' -Method $operation -body (ConvertTo-Json $messageBody)


            # Update the site with CIDR information ...
            $included_targets = [String[]]$_.value.addresses
            $uri = "https://${server}:${port}/api/3/$resource/$siteID/included_targets" 
            $resp = Invoke-RestMethod -URI $uri -Headers $headers -ContentType 'application/json' -Method $operation -body (ConvertTo-Json $included_targets)

        } catch { 

            $err=$_.Exception
            Write-Host "`n$err.Response`n" -ForegroundColor red
        }
    }
}
