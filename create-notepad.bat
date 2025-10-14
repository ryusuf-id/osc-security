@echo off
REM === Buat file notepad di desktop dengan isi tertentu ===

set "desktop=%USERPROFILE%\Desktop"
set "filename=%desktop%\catatan_ansible.txt"

echo Dibuat oleh ansible > "%filename%"

echo File berhasil dibuat di: %filename%
pause