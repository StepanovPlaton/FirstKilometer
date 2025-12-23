#!/bin/bash

DB_NAME=${POSTGRES_DB:-API}
DB_USER=${POSTGRES_USER:-API_user}
BACKUP_DIR="/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="$BACKUP_DIR/db_$TIMESTAMP.7z"

echo "[$TIMESTAMP] Starting backup..."

# Экспортируем пароль для pg_dump
export PGPASSWORD=$POSTGRES_PASSWORD

# pg_dump передает данные в 7z
# -si"db.sql" говорит 7zip, что входящий поток из stdin нужно назвать внутри архива "db.sql"
# -mx=9 устанавливает максимальный уровень сжатия (Ultra)
# -m0=lzma2 использует алгоритм LZMA2
pg_dump -U $DB_USER $DB_NAME | 7z a -si"db_dump_$TIMESTAMP.sql" -mx=9 -m0=lzma2 "$FILENAME"

# Удаляем старые бэкапы старше 7 дней
find $BACKUP_DIR -type f -name "*.7z" -mtime +7 -delete

echo "[$TIMESTAMP] Backup completed: $FILENAME"
