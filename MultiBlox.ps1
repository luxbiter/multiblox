
[CmdletBinding()]
param(
    [string]$PlaceId,
    [string]$JobId,
    [switch]$NoKill
)

$ErrorActionPreference = 'Stop'
$MutexName   = 'ROBLOX_singletonMutex'
$EventName   = 'ROBLOX_singletonEvent'
$RobloxProcs = @('RobloxPlayerBeta', 'RobloxCrashHandler')

function Get-RobloxProcs {
    Get-Process -Name $RobloxProcs -ErrorAction SilentlyContinue
}

function Close-Roblox {
    <#
        .SYNOPSIS
        Forcibly terminate every Roblox client process and wait until they are
        fully gone (taskkill returning is not enough: handles/kernel objects
        can linger until teardown completes).
    #>
    $found = Get-RobloxProcs
    if (-not $found) { return }

    Write-Warning "[MultiBlox] Found $($found.Count) Roblox process(es) - closing them to claim the singleton lock:"
    $found | ForEach-Object {
        Write-Warning "  PID $($_.Id)  $($_.ProcessName)  (started $($_.StartTime.ToString('HH:mm:ss')))"
    }

    foreach ($name in $RobloxProcs) {
        Start-Process taskkill -ArgumentList "/F /IM `"$name.exe`" /T" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    }

    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 300
        $left = Get-RobloxProcs
    } while ($left -and (Get-Date) -lt $deadline)

    if ($left) {
        $left | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        $left = Get-RobloxProcs
    }
    if ($left) {
        Write-Warning "[MultiBlox] Could not fully close Roblox - continuing anyway and trying to acquire the lock."
    } else {
        Write-Host "[MultiBlox] All Roblox processes closed." -ForegroundColor Green
    }
}

function Acquire-Lock {
    <#
        .SYNOPSIS
        Acquire the ROBLOX_singletonMutex object. Returns the mutex object.
        Throws if the lock is held by a live process and -NoKill is set.
    #>
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        $createdNew = $false
        $m = New-Object System.Threading.Mutex($true, $MutexName, [ref]$createdNew)
        if ($createdNew) {
            return $m
        }
        try {
            if ($m.WaitOne([TimeSpan]::Zero)) { return $m }
        } catch [System.Threading.AbandonedMutexException] {
            return $m
        }
        $m.Close()
        if ($NoKill) {
            Write-Warning "[MultiBlox] Lock is held by another live process (-NoKill set, not touching it)."
            Write-Warning "Close every Roblox instance (Task Manager > RobloxPlayerBeta.exe), then retry."
            Write-Warning "Also make sure no other multi-instance tool (Bloxstrap tray, RAM, etc.) is running."
            throw "Lock held by another process"
        }
        Close-Roblox
    }
    throw "Failed to acquire the singleton lock after closing Roblox (3 attempts)"
}

$mutex = Acquire-Lock

Write-Host "[MultiBlox] Lock acquired." -ForegroundColor Green

try {
    $null = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::ManualReset, $EventName)
    Write-Host "[MultiBlox] Event object acquired" -ForegroundColor Green
} catch {
    Write-Host "[MultiBlox] Event object already exists (nothing to do)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " MultiBlox is active - do NOT close this window!" -ForegroundColor Cyan
Write-Host " Launch Roblox from your browser as many times as" -ForegroundColor Cyan
Write-Host " you like; every window will open normally."       -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

if ($PlaceId) {
    $uri = "roblox://experiences/start?placeId=$PlaceId"
    if ($JobId) { $uri += "&gameInstanceId=$JobId" }
    Start-Process $uri
    Write-Host "[MultiBlox] Launch URI: $uri" -ForegroundColor Green
    Start-Sleep -Seconds 3
}

Write-Host "[MultiBlox] Holding the lock... (press Ctrl+C to quit)"
try {
    while ($true) { Start-Sleep -Seconds 3600 }
} finally {
    try { $mutex.ReleaseMutex() } catch {}
    $mutex.Close()
}
