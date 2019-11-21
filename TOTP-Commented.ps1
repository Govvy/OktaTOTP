[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$apikey = "SSWS {insert your secret here}" #provide API key (Org Admin role is enough)
$org = "https://{your-org}.okta.com/" #provide the Okta Org URL
$factorProfile = "insert your factor profile id" #in MFA section of TOTP config the creation generates a unique identifier
$user = Read-Host -Prompt 'input the user email' #email of user you want to enrol TOTP token

#perform lookup of user in your Okta Org
$uri = "$org" + "/api/v1/users/" + "$user" 
$webrequest = Invoke-WebRequest -TimeoutSec 300 -Headers @{"Authorization" = $apiKey} -Method Get -Uri $uri

#perform lookup of user id in your Okta Org (this is needed for the subsequent API requests)
$id = $webrequest.Content | ConvertFrom-Json | ft id -HideTableHeaders
$id1 = $id | Out-String
$id2 = $id1.Trim()

#lookup exsiting factor enrolment for user
$uri2 = "$org" + "/api/v1/users/" + "$id2" + "/factors"
$webrequest = Invoke-WebRequest -TimeoutSec 300 -Headers @{"Authorization" = $apiKey} -Method Get -Uri $uri2
$factor = $webrequest.Content | ConvertFrom-Json
$factorStr = $factor | Out-String

#check if TOTP factor is already enrolled otherwise perform enrolment
if ($factorStr.Contains("hotp")) { Write-Host -NoNewLine -ForegroundColor Green "TOTP Factor Already Enrolled";$factorStr } else {
$mfa = "$org" + "api/v1/users/" + "$id2" + "/factors/?activate=true"

#add user to group controlling the enrolment policy for TOTP
$grp = "$org" + "api/v1/groups/{insert your enrolment policy group id here}/users/" + "$id2"
$webrequest = Invoke-WebRequest -TimeoutSec 300 -Headers @{"Authorization" = $apiKey;"Accept"="application/json";"Content-Type"="application/json"} -Method PUT -Uri $grp

#requst input of TOTP secret
$hex = Read-Host -Prompt 'input the totp secret'

$json = @"

{
  "factorType": "token:hotp",
  "provider": "CUSTOM",
  "factorProfileId": "$factorProfile",
  "profile": {
      "sharedSecret": "$hex"
  }
}

"@

$body = $json | ConvertTo-Json

#perform enrolment via API with json body above (error code will be caught and displayed if there is a problem)

try { $webrequest = Invoke-WebRequest -TimeoutSec 300 -Headers @{"Authorization" = $apiKey;"Accept"="application/json";"Content-Type"="application/json"} -Method POST -Uri $mfa -Body $json
} catch {
      $_.Exception.Response.StatusCode.Value__}
}