# --- CONFIGURATION ---
$BaseDir   = "C:\Users\Kingadmin\Desktop\BFAtk-Avenger"
$LogFile   = "$BaseDir\Blocked_Audit_Log.txt"
$Threshold = 3   # Block IP if attempts are GREATER than this
$TimeSpan  = 24  # Look back at the last 24 hours

# Safety Whitelist
$Whitelist = @("127.0.0.1", "::1", "192.168.1.10") 

# --- INITIALIZATION ---
if (!(Test-Path $BaseDir)) { New-Item -ItemType Directory -Path $BaseDir | Out-Null }

function Write-AuditLog {
    param ($Message)
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Date] $Message"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry -ForegroundColor Yellow
}

Write-Host "Starting BFAtk-Avenger Scan..." -ForegroundColor Cyan

# --- 1. GET FAILED LOGINS ---
try {
    # Get Event ID 4625 (Failed Logon)
    $Events = Get-WinEvent -FilterHashtable @{
        LogName   = 'Security'
        ID        = 4625
        StartTime = (Get-Date).AddHours(-$TimeSpan)
    } -ErrorAction Stop
    
    Write-Host "Found $($Events.Count) failed login events." -ForegroundColor Cyan
}
catch {
    # FIX: Explicitly handle cases where no logs exist
    if ($_.Exception.Message -like "*No events were found*") {
        $Msg = "SUCCESS: No failed login attempts found in the last $TimeSpan hours."
        Write-Host $Msg -ForegroundColor Green
        
        # ADDED: Write this success to the log file so you know it ran
        Write-AuditLog "INFO: Scan Clean. No attackers detected." 
        exit
    }
    elseif ($_.Exception.Message -like "*Access is denied*") {
        Write-Host "ERROR: Access Denied. Please Run as Administrator." -ForegroundColor Red
        Write-AuditLog "ERROR: Script failed. Access Denied (Not Admin)."
        exit
    }
    else {
        # Catch-all for other errors
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-AuditLog "ERROR: Unexpected error - $($_.Exception.Message)"
        exit
    }
}

# --- 2. EXTRACT AND GROUP IPs ---
# First, we get ALL IPs and group them to see the counts
$AllIPs = $Events | ForEach-Object {
    $xml = [xml]$_.ToXml()
    $xml.Event.EventData.Data | Where-Object { $_.Name -eq 'IpAddress' } | Select-Object -ExpandProperty '#text'
} | Group-Object | Sort-Object Count -Descending

# --- 3. PRINT BREAKDOWN ---
if ($AllIPs) {
    Write-Host "`n--- ATTACKER BREAKDOWN ---" -ForegroundColor Yellow
    $AllIPs | ForEach-Object {
        Write-Host "IP: $($_.Name) - Attempts: $($_.Count)"
    }
    Write-Host "--------------------------`n" -ForegroundColor Yellow
}

# --- 4. FILTER FOR BLOCKING ---
# Now we select only those who crossed the line
$BadIPs = $AllIPs | Where-Object { $_.Count -gt $Threshold }

# --- 5. BLOCKING LOGIC ---
foreach ($Item in $BadIPs) {
    $TargetIP = $Item.Name
    $Count    = $Item.Count

    # Clean up: Skip empty, dash (-), or Whitelisted IPs
    if ([string]::IsNullOrWhiteSpace($TargetIP) -or $TargetIP -eq "-" -or ($TargetIP -in $Whitelist)) {
        continue
    }

    $RuleName = "BF_Block_$TargetIP"
    $ExistingRule = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue

    if (-not $ExistingRule) {
        try {
            New-NetFirewallRule -DisplayName $RuleName `
                                -Direction Inbound `
                                -Action Block `
                                -RemoteAddress $TargetIP `
                                -Description "Blocked by BFAtk-Avenger. Failed: $Count" `
                                -ErrorAction Stop | Out-Null

            Write-AuditLog "ACTION: BLOCKED IP $TargetIP - Reason: $Count failed attempts."
        }
        catch {
            Write-AuditLog "ERROR: Failed to block $TargetIP - $($_.Exception.Message)"
        }
    }
    else {
        # Optional: Log that we saw them again
        Write-AuditLog "INFO: Skipped $TargetIP (Already Blocked). Still attacking ($Count attempts)."
    }
}