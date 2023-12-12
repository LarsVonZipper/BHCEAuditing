<#
BloodHoundCE API Ingest Process:
    1. log in to BloodHoundCE
    2. request an upload job
    3. create the upload job
    4. upload .json file to be ingested
    5. end job

PLEASE NOTE:
    Hardcoded with 'http://localhost:8080' as BloodHoundCE API location. Amend as necessary

#>

$fullFilePath = Read-Host "Enter full path of .json file to upload"

# test if file to upload exists
if (Test-Path $fullFilePath) {
    Write-Host " [info] File to upload exists" -ForegroundColor:Green
}
else {
    Write-Host " [ERRR] File cannot be found!" -ForegroundColor:Red
    break
}

$bloodHoundCredentials = Get-Credential -Message "Enter login details for BloodHound CE"

# logging in... (get a session token)
Write-Host " [info] Logging in..." -ForegroundColor:Green

$loginPayload = @{
    login_method = "secret"
    secret       = $($bloodHoundCredentials.GetNetworkCredential().Password)
    username     = $($bloodHoundCredentials.GetNetworkCredential().UserName)
}

$loginResponse = Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/api/v2/login'-Body ($loginPayload | ConvertTo-Json) -ContentType 'application/json'

# request upload job
if ($loginResponse.StatusCode -eq 200) {
    $sessionToken = ($loginResponse.Content | ConvertFrom-Json).data.session_token
    Write-Host " [info] Successful login" -ForegroundColor:Green
    Write-Host " [info] Requesting upload job" -ForegroundColor:Green

    $loginHeaders = @{
        'Accept'        = "application/json, text/plain, */*"
        'Authorization' = "Bearer $sessionToken"
    }

    $uploadJobResponse = Invoke-WebRequest -Method Post -Uri 'http://localhost:8080/api/v2/file-upload/start' -Headers $loginHeaders
    
    # creating upload job
    if ($uploadJobResponse.StatusCode -eq 201) {
        $uploadJobResponseContent = $uploadJobResponse.Content | ConvertFrom-Json
        Write-Host " [info] Created upload job: id = $($uploadJobResponseContent.data.id)" -ForegroundColor:Green

        # upload file
        Write-Host " [info] Uploading file $fullFilePath" -ForegroundColor:Green

        $uploadDataHeaders = @{
            'Accept'        = "application/json, text/plain, */*"
            'Authorization' = "Bearer $sessionToken"
            'Content-Type'  = "application/x-www-form-urlencoded"
        }

        $uploadDataBody = Get-Content $fullFilePath -Encoding UTF8
        $uploadDataUri = "http://localhost:8080/api/v2/file-upload/$($uploadJobResponseContent.data.id)"
        $uploadDataResponse = Invoke-WebRequest -Method Post -Uri $uploadDataUri -Headers $uploadDataHeaders -Body $uploadDataBody
        
        if ($uploadDataResponse.StatusCode -eq 202) {
            Write-Host " [info] upload complete" -ForegroundColor:Green
            Write-Host " [info] waiting 10 seconds to assert file upload complete... " -NoNewline -ForegroundColor:Green
            Start-Sleep 10
            Write-Host "Done" -ForegroundColor:Green
        }
        else {
            Write-Host " [ERRR] Something went wrong!" -ForegroundColor:Red
        }

        # end job
        Write-Host " [info] ending job... " -NoNewline -ForegroundColor:Green
                
        $endJobHeaders = @{
            'Accept'          = "application/json, text/plain, */*"
            'Accept-Language' = "en-US,en;q=0.9,es;q=0.8,fr;q=0.7"
            'Authorization'   = "Bearer $sessionToken"
        }

        $endJobUri = "http://localhost:8080/api/v2/file-upload/$($uploadJobResponseContent.data.id)/end"
        $endJobResponse = Invoke-WebRequest -Method Post -Uri $endJobUri -Headers $endJobHeaders
        
        if ($endJobResponse.StatusCode -eq 200) {
            Write-Host "Done" -ForegroundColor:Green
            Write-Host " [info] Completed uploading file." -ForegroundColor:Green
            Write-Host " [info] Check the BloodhoundCE UI for processing information" -ForegroundColor:Cyan
        }
        else {
            Write-Host " [ERRR] Something went wrong!" -ForegroundColor:Red
        }        
    }
    else {
        Write-Host " [ERRR] unable to create upload job!" -ForegroundColor:Red
        break
    }
} 
else {
    Write-Host " [ERRR] unsuccessful login to BloodHoundCE!" -ForegroundColor:Red
    break
}