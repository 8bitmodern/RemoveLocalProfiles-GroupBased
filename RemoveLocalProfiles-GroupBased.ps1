$GroupName = "AccountDataRemoval"
$LogFile = "C:\Logs\AccountDataRemoval.log"

# Create log directory if needed
$LogDir = Split-Path $LogFile -Parent

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File $LogFile -Append -Encoding UTF8
}

Write-Log "===== Account Data Removal Started ====="
Write-Log "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Log "Computer: $env:COMPUTERNAME"

# Verify SYSTEM
if (-not ([System.Security.Principal.WindowsIdentity]::GetCurrent().IsSystem)) {
    Write-Log "ERROR: Script is not running as SYSTEM."
    exit 1
}

# ------------------------------------------------------------------
# Get LOCAL group members instead of Active Directory group members
# ------------------------------------------------------------------

try {

    Write-Log "Searching for local group: $GroupName"

    $group = [ADSI]"WinNT://$env:COMPUTERNAME/$GroupName,group"

    $members = @($group.psbase.Invoke("Members"))

    if (-not $members -or $members.Count -eq 0) {
        Write-Log "No members found in local group '$GroupName'"
    }

}
catch {
    Write-Log "ERROR accessing local group '$GroupName'"
    Write-Log $_.Exception.Message
    exit 1
}

# Build local user/SID list
$usersFromGroup = foreach ($member in $members) {

    try {

        $adsPath = $member.GetType().InvokeMember(
            "ADsPath",
            'GetProperty',
            $null,
            $member,
            $null
        )

        $user = [ADSI]$adsPath

        $name = $user.Name[0]

        try {
            $account = New-Object System.Security.Principal.NTAccount(
                "$env:COMPUTERNAME",
                $name
            )

            $sid = $account.Translate(
                [System.Security.Principal.SecurityIdentifier]
            )

            [PSCustomObject]@{
                Name = $name
                SID  = $sid.Value
            }
        }
        catch {
            Write-Log "Unable to resolve SID for local user: $name"
        }
    }
    catch {
        Write-Log "Failed processing local group member"
        Write-Log $_.Exception.Message
    }
}

Write-Log "Users found in local group: $($usersFromGroup.Count)"

# ------------------------------------------------------------------
# Get local profiles
# ------------------------------------------------------------------

try {
    $profiles = Get-CimInstance Win32_UserProfile
}
catch {
    Write-Log "ERROR retrieving profiles: $($_.Exception.Message)"
    exit 1
}

# ------------------------------------------------------------------
# Remove orphaned profiles
# ------------------------------------------------------------------

Write-Log "Checking for unresolved/orphaned profiles..."

foreach ($profile in $profiles) {

    if ($profile.Special -or $profile.Loaded) {
        continue
    }

    try {

        $sid = New-Object System.Security.Principal.SecurityIdentifier($profile.SID)

        $null = $sid.Translate([System.Security.Principal.NTAccount])

        # SID resolved successfully -> not orphaned
        continue
    }
    catch {

        Write-Log "ORPHANED PROFILE DETECTED"
        Write-Log "  SID    : $($profile.SID)"
        Write-Log "  Path   : $($profile.LocalPath)"
        Write-Log "  Loaded : $($profile.Loaded)"

        try {
            Remove-CimInstance $profile
            Write-Log "SUCCESS: Orphaned profile removed."
        }
        catch {
            Write-Log "ERROR removing orphaned profile: $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------------------
# Remove profiles for users in local group
# ------------------------------------------------------------------

foreach ($user in $usersFromGroup) {

    $profile = $profiles | Where-Object {
        $_.SID -eq $user.SID
    }

    if (-not $profile) {
        Write-Log "No profile found for $($user.Name) ($($user.SID))"
        continue
    }

    if ($profile.Loaded) {
        Write-Log "Skipping loaded profile: $($user.Name)"
        continue
    }

    if ($profile.Special) {
        Write-Log "Skipping special profile: $($user.Name)"
        continue
    }

    $sizeGB = 0

    try {

        if (Test-Path $profile.LocalPath) {

            $size = (
                Get-ChildItem $profile.LocalPath -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum
            ).Sum

            if ($size) {
                $sizeGB = [math]::Round(($size / 1GB), 2)
            }
        }
    }
    catch {
        Write-Log "Unable to calculate size for $($profile.LocalPath)"
    }

    Write-Log "Deleting profile:"
    Write-Log "  User : $($user.Name)"
    Write-Log "  SID  : $($user.SID)"
    Write-Log "  Path : $($profile.LocalPath)"
    Write-Log "  Size : $sizeGB GB"

    try {
        Remove-CimInstance $profile
        Write-Log "SUCCESS: Profile removed."
    }
    catch {
        Write-Log "ERROR removing profile: $($_.Exception.Message)"
    }
}

Write-Log "===== Account Data Removal Finished ====="
