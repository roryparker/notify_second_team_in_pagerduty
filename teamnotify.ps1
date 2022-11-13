<#
.SYNOPSIS
Notifies the a second Team of Priority Level 1 (SEV-1/P1) incidents in PagerDuty using an existing Response Play based on the RP ID
.DESCRIPTION
We only want the Response Play to run on (SEV-1) listed Priority Level incidents. Currently Response Plays do not do this inside PagerDuty.
Response Plays can either be run on-demand or automatically at incident creation, but are limited to how they can be run.
If you configure a Response Play to run on a Service under Settings → Coordinate Responders and Stakeholders → Response Play,
it will be run for all High-Urgency incidents regardless of their Priority level. The same Response Play can be configured to run
on several Services at incident creation.

https://support.pagerduty.com/docs/response-plays
https://support.pagerduty.com/docs/event-orchestration

.NOTES
FunctionName : Notify-Commanders
Created by   : Rory Parker
Date Coded   : 08/31/2022 22:00:00
More info    : N/A
#>


BEGIN {
#Gathers list of RP to identify the Incident Commanders Response Play and output them to the screen. This is also used for debugging
function Get-ResponsePlaysList {
    $headers=@{}
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/vnd.pagerduty+json;version=2")
    $headers.Add("From", "rory.parker@bump.com")
    $headers.Add("Authorization", "Token token=yyyyyyyyyyyy")
    $response = Invoke-RestMethod -Uri 'https://api.pagerduty.com/response_plays' -Method GET -Headers $headers
    return $response
}

# For Debugging
$responsePlayHashTable = Get-ResponsePlaysList
Write-Output $responsePlayHashTable | ConvertTo-Json

###################

# Gathers incident list

function Get-Incidents {
    $headers=@{}
    $headers.Add("Content-Type", "application/json")
    $headers.Add("Accept", "application/vnd.pagerduty+json;version=2")
    $headers.Add("Authorization", "Token token=u+emXEx-tD4MywTRU4Cg")
    $response = Invoke-RestMethod -Uri 'https://api.pagerduty.com/incidents?limit=100&ttal=true' -Method GET -Headers $headers
    return $response
}
$incidentHashtable = Get-Incidents

# For Debugging
Write-Output $incidentHashtable.incidents | ConvertTo-Json

}

PROCESS {
# Loop over the Incident Hashtable
ForEach ($incident in $incidentHashtable.incidents) {

    # Build variables to target specific sections for the filter.
    $incidentCommandersResponsePlayID = "170db24c-dad8-8bd4-87bf-fbdff0b2b0b7" # Incident Commanders ID
    $incidentId = $incident.id
    $URL = "https://api.pagerduty.com/response_plays/$incidentCommandersResponsePlayID/run"

    # Use Splatting/Hastable instead of raw JSON for the -Body parameter
    $incidenthash = @{
        "incident" = @{
            "id" = $incidentId
            "type" = "incident"
            "status" = $incident.status
            "priority" = $incident.priority.summary
            "summary"= "[#1234567890] This confirms that the Response Play sent an email to you. Please respond. Thanks."
            "self"= "https://api.pagerduty.com/incidents/$incidentId"
            "html_url"= "https://hrb-sandbox.pagerduty.com/incidents/$incidentId"
        }
    }
    $incidentbody = $incidenthash | ConvertTo-Json

    # Filter incidents in the Hashtable based on status(triggered), urgency(high), and priority (SEV-1)
    if ((($incident.status -eq "triggered") -and ($incident.urgency -eq "high")) -and (($incident.priority.summary -eq "SEV-1") -or ($incident.priority -eq "SEV-1"))) {

        # Run the Response Play to notify Incident Commanders. This should return a "status 200 ok". Setup a breakpoint on line 85 (response) for testing.
        function Start-ResponsePlay {
            $headers=@{}
            $headers.Add("Content-Type", "application/json")
            $headers.Add("Accept", "application/vnd.pagerduty+json;version=2")
            $headers.Add("From", "rory.parker@hrblock.com")
            $headers.Add("Authorization", "Token token=u+emXEx-tD4MywTRU4Cg")
            $response = Invoke-WebRequest -Uri $URL -Method POST -Headers $headers -ContentType 'application/json' -Body $incidentbody

            return $response
            }
        Start-ResponsePlay
        }
    }
}
