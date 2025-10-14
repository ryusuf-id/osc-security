# Tentukan path Desktop untuk semua user atau user saat ini
$desktopPath = [Environment]::GetFolderPath("Desktop")

# Tentukan nama file
$filePath = Join-Path $desktopPath "Dibuat_Oleh_Ansible.txt"

# Tulis isi file
"**DIBUAT OLEH ANSIBEL**" | Out-File -FilePath $filePath -Encoding UTF8

# Tampilkan pesan konfirmasi
Write-Host "File berhasil dibuat di: $filePath"
