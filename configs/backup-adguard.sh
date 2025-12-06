#!/bin/bash
# backup_adguard.sh
# =================
# Script para realizar backup diário dos volumes do AdGuardHome
# Diretórios dos volumes:
# - /var/lib/docker/volumes/adguard_config
# - /var/lib/docker/volumes/adguard_work
# - /var/lib/docker/volumes/adguard_logs
# Mantém últimos 7 dias de backup.

# Diretório onde os backups serão armazenados
BACKUP_DIR="/root/adguard_backup"
DATE=$(date +"%Y-%m-%d")

# Diretórios dos volumes do AdGuardHome
VOLUMES=(
    "/var/lib/docker/volumes/adguard_config"
    "/var/lib/docker/volumes/adguard_work"
    "/var/lib/docker/volumes/adguard_logs"
)

# Nomes amigáveis dos volumes para os arquivos
VOLUME_NAMES=("adguard_config" "adguard_work" "adguard_logs")

# Cria diretório de backup se não existir
mkdir -p $BACKUP_DIR

echo "==========================================="
echo "Iniciando backup do AdGuardHome: $DATE"
echo "Backup será salvo em: $BACKUP_DIR"
echo "==========================================="

# Opcional: parar o container antes do backup para consistência
echo "Parando container AdGuardHome para backup seguro..."
docker stop adguardhome

# Loop para criar backups de cada volume
for i in "${!VOLUMES[@]}"; do
    VOL_PATH="${VOLUMES[$i]}"
    VOL_NAME="${VOLUME_NAMES[$i]}"
    BACKUP_FILE="${BACKUP_DIR}/${VOL_NAME}_${DATE}.tar.gz"

    echo "Fazendo backup do volume $VOL_NAME..."
    tar czf "$BACKUP_FILE" -C "$VOL_PATH" .
done

# Reinicia o container após backup
echo "Reiniciando container AdGuardHome..."
docker start adguardhome

# Remove backups antigos (mais de 7 dias)
echo "Removendo backups com mais de 7 dias..."
find $BACKUP_DIR -type f -mtime +7 -name "*.tar.gz" -exec rm {} \;

echo "Backup concluído com sucesso!"
echo "==========================================="
