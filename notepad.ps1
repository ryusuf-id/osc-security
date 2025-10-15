# install_notepadpp.ps1
# PowerShell script untuk menginstal Notepad++ secara silent dari C:\elastic-agent
# 2025 - dibuat untuk pengguna: mencari exe yang mengandung "notepad" dan mencoba beberapa opsi silent
# Log file: C:\elastic-agent\install-notepadpp.log

$ErrorActionPreference = 'Stop'
$logFile = 'C:\elastic-agent\install-notepadpp.log'

function Write-Log {
    param([string]$msg)
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "$timestamp`t$msg"
    $line | Out-File -FilePath $logFile -Encoding utf8 -Append
    Write-Output $line
}

# Pastikan folder ada
$installFolder = 'C:\elastic-agent'
if (-not (Test-Path -Path $installFolder)) {
    Write-Log "ERROR: Folder $installFolder tidak ditemukan."
    throw "Folder $installFolder tidak ditemukan."
}

# Elevate if not running as admin
function Test-IsAdmin {
    try {
        $current = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($current)
        return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    } catch {
        return $false
    }
}

if (-not (Test-IsAdmin)) {
    Write-Log "Script belum dijalankan sebagai Administrator — mencoba elevasi..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb = 'runas'
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        exit $proc.ExitCode
    } catch {
        Write-Log "ERROR: Gagal elevasi: $_"
        throw "Gagal elevasi: $_"
    }
}

Write-Log "Mulai instalasi Notepad++ dari folder $installFolder"

# CARI installer exe yang mengandung 'notepad' (case-insensitive)
$installerCandidates = Get-ChildItem -Path $installFolder -Filter *.exe -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '(?i)notepad' } |
    Sort-Object LastWriteTime -Descending

if (-not $installerCandidates -or $installerCandidates.Count -eq 0) {
    Write-Log "ERROR: Tidak menemukan file installer Notepad++ (*.exe) di $installFolder"
    throw "Tidak menemukan file installer Notepad++ (*.exe) di $installFolder"
}

$installer = $installerCandidates[0].FullName
Write-Log "Ditemukan installer: $installer (menggunakan file paling baru yang cocok)"

# Fungsi cek apakah Notepad++ sudah terpasang (mencari nama pada registry uninstall)
function Get-NotepadPPInstalled {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($k in $keys) {
        try {
            Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -and ($_.DisplayName -match '(?i)notepad\+\+' -or $_.DisplayName -match '(?i)notepad') } |
                Select-Object -First 1 | ForEach-Object { return $_ }
        } catch {
            # ignore
        }
    }
    return $null
}

$already = Get-NotepadPPInstalled
if ($already) {
    Write-Log "INFO: Notepad++ sudah terdeteksi terpasang: $($already.DisplayName) - melewati instalasi."
    exit 0
}

# Daftar argumen silent umum yang akan dicoba (urutan prioritas)
# Catatan: installer Notepad++ (NSIS) umumnya mendukung /S ; beberapa installer MSI/others mungkin support /quiet
$silentArgsList = @(
    '/S',                             # NSIS common silent
    '/VERYSILENT /NORESTART',         # Inno/NSIS variants
    '/SILENT /NORESTART',             # alternatif
    '/quiet /norestart',              # MSI-like
    '/qn /norestart'                  # MSI msiexec style (if wrapper)
)

$installed = $false
foreach ($arg in $silentArgsList) {
    Write-Log "Mencoba instalasi dengan argumen: $arg"
    try {
        $startInfo = Start-Process -FilePath $installer -ArgumentList $arg -Wait -PassThru -NoNewWindow
        $exitCode = $startInfo.ExitCode
        Write-Log "Proses selesai. ExitCode = $exitCode"
        # treat exit code 0 as success
        if ($exitCode -eq 0) {
            # verifikasi apakah terinstal
            Start-Sleep -Seconds 2
            $already = Get-NotepadPPInstalled
            if ($already) {
                Write-Log "SUCCESS: Notepad++ berhasil diinstal. $($already.DisplayName)"
                $installed = $true
                break
            } else {
                Write-Log "WARNING: ExitCode 0 tetapi entri uninstall Notepad++ tidak ditemukan. Melanjutkan pengecekan..."
                # mungkin portable installer; cek apakah exe muncul di Program Files
            }
        } else {
            Write-Log "INFO: ExitCode bukan 0 ($exitCode). Mencoba argumen berikutnya."
        }
    } catch {
        Write-Log "ERROR saat menjalankan installer dengan argumen '$arg': $_"
    }
}

if (-not $installed) {
    # Coba cara fallback: jalankan tanpa argumen (user interactive) tapi tetap menunggu dan mencatat exit code
    Write-Log "Mencoba fallback: menjalankan installer tanpa argumen (interactive) — ini mungkin memerlukan interaksi manual."
    try {
        $p = Start-Process -FilePath $installer -Wait -PassThru
        Write-Log "Fallback selesai. ExitCode = $($p.ExitCode)"
        Start-Sleep -Seconds 2
        $already = Get-NotepadPPInstalled
        if ($already) {
            Write-Log "SUCCESS (fallback): Notepad++ berhasil diinstal."
            $installed = $true
        } else {
            Write-Log "GAGAL: Instalasi Notepad++ tidak terdeteksi setelah mencoba semua opsi."
        }
    } catch {
        Write-Log "ERROR saat menjalankan fallback installer: $_"
    }
}

if ($installed) {
    Write-Log "Selesai: Notepad++ terpasang."
    exit 0
} else {
    Write-Log "Selesai: Notepad++ tidak terpasang. Periksa log dan jalankan installer secara manual jika perlu."
    exit 1
}
