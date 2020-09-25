$appid = Start-Process ./standalone.bat -windowstyle hidden -passthru

function checkStatus {
    if ($args[0] -notmatch $args[1]) {
        Get-WmiObject Win32_Process -filter "CommandLine LIKE '%alfresco-identity-service-$IDENTITY_VERSION%'" | foreach { kill $_.ProcessId }
        $test=$args[0]
        $check=$args[1]
        throw "Accessing $test does not output $check "
    }
}

$COUNTER = 0
$COUNTER_MAX = 60
$SLEEP_SECONDS = 1
$SERVICEUP = 0
Do {
    $result = (curl -UseBasicParsing -v http://localhost:8080/auth/).StatusCode
    if ($result -eq "200") {
        $SERVICEUP =1
    } else {
        start-sleep -s $SLEEP_SECONDS
        $COUNTER++
    }
   
} While ($SERVICEUP -eq 0 -and $COUNTER -lt $COUNTER_MAX) 

if ($SERVICEUP -ne 1) {
    throw "Identity Service timed out "
}

checkStatus (curl -UseBasicParsing -v http://localhost:8080/auth/).StatusCode "200"
checkStatus (curl -UseBasicParsing -v http://localhost:8080/auth/admin/alfresco/console/).StatusCode "200"
checkStatus (curl -UseBasicParsing  "http://localhost:8080/auth/realms/alfresco/account").Content "Identity"
$Body = @{
   client_id = "alfresco"
   username = "admin"
   password = "admin"
   grant_type = "password"
}
checkStatus (Invoke-RestMethod "http://localhost:8080/auth/realms/alfresco/protocol/openid-connect/token" -Method Post -Body $Body).access_token "."

$parentproc = $appid.ID
write-output $parentproc
wmic path win32_process where parentprocessid=$parentproc

$scriptBlock =  {                 
        function Kill-ChildProcess(){
            param($ID=$PID)
                $CustomColumnID = @{
                Name = 'Id'
                Expression = { [Int[]]$_.ProcessID }
                }

                Write-Host $ID
                $result = Get-WmiObject -Class Win32_Process -Filter ParentProcessID=$ID | Select-Object -Property ProcessName, $CustomColumnID, CommandLine
                $result | Where-Object { $_.ID -ne $null } | Stop-Process
        }

         Get-Process $args[0] -ErrorAction SilentlyContinue | ForEach {Kill-ChildProcess -id $_.ID}
         Get-Process $args[0] -ErrorAction SilentlyContinue | Stop-Process -ErrorAction SilentlyContinue;
    };


Invoke-Command -ArgumentList $parentproc -ScriptBlock $scriptBlock

Get-WmiObject Win32_Process -filter "CommandLine LIKE '%alfresco-identity-service-$IDENTITY_VERSION%'" | foreach { kill $_.ProcessId }
