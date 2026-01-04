# --- НАСТРОЙКИ ---
$ProjectPath = Get-Location 
$BackupDir = "$ProjectPath\deploy_backups"
$DocumentsDir = "$ProjectPath\documents"
$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"

$DB_CONTAINER = "firstkilometer_postgres"

$envFile = ".\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object {
        $_ -notmatch "^\s*#" -and $_ -match "\S"  # Пропускаем комментарии и пустые строки
    } | ForEach-Object {
        $name, $value = $_ -split '=', 2
        $varName = $name.Trim()
        $varValue = $value.Trim() -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1'  # убираем кавычки
        Set-Variable -Name $varName -Value $varValue -Scope Script
    }
} else {
    Write-Warning "Файл .env не найден."
}

# Создаем папку для бэкапов, если нет
if (!(Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Output "--- Starting Deployment [$Timestamp] ---" -ForegroundColor Cyan

# 1. ОБНОВЛЕНИЕ РЕПОЗИТОРИЯ
Write-Output ">>> Updating repository..." -ForegroundColor Yellow
git pull origin main
git submodule update --init --recursive

# 2. БЭКАП БАЗЫ ДАННЫХ
Write-Output ">>> Creating Database backup..." -ForegroundColor Yellow
$DbBackupName = "db_before_deploy_$Timestamp.7z"

# Делаем дамп и сжимаем
docker exec $DB_Container pg_dump -U $POSTGRES_USER $POSTGRES_DB > "$BackupDir\temp_db.sql"
& $SevenZipPath a -mx=9 -m0=lzma2 "$BackupDir\$DbBackupName" "$BackupDir\temp_db.sql"
Remove-Item "$BackupDir\temp_db.sql"

# 3. БЭКАП ФАЙЛОВ (директория documents)
Write-Output ">>> Creating Documents backup..." -ForegroundColor Yellow
$DocBackupName = "docs_backup_$Timestamp.7z"
& $SevenZipPath a -mx=9 -m0=lzma2 "$BackupDir\$DocBackupName" "$DocumentsDir"

# 4. РОТАЦИЯ БЭКАПОВ (Оставляем только 2 последних для каждого типа)
Write-Output ">>> Rotating old backups..." -ForegroundColor Yellow

# Функция для безопасного удаления
function Remove-OldFiles {
    param([string]$Pattern, [string]$CurrentFile)
    
    # Получаем все файлы по маске, исключаем текущий (только что созданный), 
    # сортируем по ИМЕНИ (потому что там дата) и пропускаем 2 самых свежих.
    $FilesToDelete = Get-ChildItem $Pattern | 
                     Where-Object { $_.Name -ne $CurrentFile } | 
                     Sort-Object Name -Descending | 
                     Select-Object -Skip 2

    foreach ($file in $FilesToDelete) {
        Remove-Item $file.FullName -Force
        Write-Output "Removed old backup: $($file.Name)" -ForegroundColor Gray
    }
}

# Ротация для документов
Remove-OldFiles -Pattern "$BackupDir\docs_backup_*.7z" -CurrentFile $DocBackupName

# Ротация для базы данных
Remove-OldFiles -Pattern "$BackupDir\db_before_deploy_*.7z" -CurrentFile $DbBackupName

# 5. ПЕРЕЗАПУСК DOCKER
Write-Output ">>> Rebuilding and starting containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

# 6. ОЧИСТКА
# docker image prune -f

Write-Output "--- Deployment Finished Successfully ---" -ForegroundColor Green