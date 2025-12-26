# --- НАСТРОЙКИ ---
$ProjectPath = Get-Location # Предполагаем, что запуск из папки проекта
$BackupDir = "$ProjectPath\backups_host"
$DocumentsDir = "$ProjectPath\documents"
$SevenZipPath = "7z" #"C:\Program Files\7-Zip\7z.exe"

# Настройки БД (согласно вашему compose)
$DB_Container = "firstkilometer_postgres"
$DB_User = "firstkilometer_databaseuser"
$DB_Name = "firstkilometer"

# Создаем папку для бэкапов на хосте, если нет
if (!(Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "--- Starting Deployment [$Timestamp] ---" -ForegroundColor Cyan

# 1. ОБНОВЛЕНИЕ РЕПОЗИТОРИЯ
Write-Host ">>> Updating repository..." -ForegroundColor Yellow
git pull origin main
git submodule update --init --recursive

# 2. БЭКАП БАЗЫ ДАННЫХ (запуск внутри контейнера)
# Мы вызываем pg_dump напрямую через docker exec, чтобы сохранить файл сразу на хост или в примонтированную папку
Write-Host ">>> Creating Database backup..." -ForegroundColor Yellow
$DbBackupName = "db_before_deploy_$Timestamp.7z"

# Вызываем pg_dump внутри и сжимаем через 7z (если 7z есть в контейнере) 
# Либо сохраняем sql и сжимаем силами Windows:
docker exec $DB_Container pg_dump -U $DB_User $DB_Name > "$BackupDir\temp_db.sql"
& $SevenZipPath a -mx=9 -m0=lzma2 "$BackupDir\$DbBackupName" "$BackupDir\temp_db.sql"
Remove-Item "$BackupDir\temp_db.sql"

# 3. БЭКАП ФАЙЛОВ (директория documents)
Write-Host ">>> Creating Documents backup..." -ForegroundColor Yellow
$DocBackupName = "docs_backup_$Timestamp.7z"

# Архивация папки documents с максимальным сжатием
& $SevenZipPath a -mx=9 -m0=lzma2 "$BackupDir\$DocBackupName" "$DocumentsDir"

# 4. РОТАЦИЯ БЭКАПОВ ФАЙЛОВ (Оставляем только 2 последних)
Write-Host ">>> Rotating old backups..." -ForegroundColor Yellow
$OldDocBackups = Get-ChildItem "$BackupDir\docs_backup_*.7z" | Sort-Object CreationTime -Descending | Select-Object -Skip 2
foreach ($file in $OldDocBackups) {
    Remove-Item $file.FullName -Force
    Write-Host "Removed old backup: $($file.Name)" -ForegroundColor Gray
}

# 5. ПЕРЕЗАПУСК DOCKER
Write-Host ">>> Rebuilding and starting containers..." -ForegroundColor Yellow
docker-compose up -d --build

# 6. ОЧИСТКА (удаление старых образов)
# docker image prune -f

Write-Host "--- Deployment Finished Successfully ---" -ForegroundColor Green