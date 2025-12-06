#!/bin/bash
# restore_adguard.sh
# ==================
# Script para restaurar volumes do AdGuardHome a partir de backups.
# Mostra os backups disponíveis para o usuário escolher.
# Diretórios de volumes:
# - /var/lib/docker/volumes/adguard_config
# - /var/lib/docker/volumes/adguard_work
# - /var/lib/docker/volumes/adguard_logs

BACKUP_DIR="/root/adguard_backup"
VOLUMES=(
    "/var/lib/docker/volumes/adguard_config"
    "/var/lib/docker/volumes/adguard_work"
    "/var/lib/docker/volumes/adguard_logs"
)
VOLUME_NAMES=("adguard_config" "adguard_work" "adguard_logs")

# Lista os backups disponíveis (datas únicas)
echo "Backups disponíveis:"
ls -1 $BACKUP_DIR | grep .tar.gz | sed -E 's/_(.*).tar.gz/\1/' | sort -u
echo "-------------------------------------------"

# Solicita a data do backup a restaurar
read -p "Digite a data do backup que deseja restaurar (AAAA-MM-DD): " DATE

# Verifica se os arquivos existem
for VOL_NAME in "${VOLUME_NAMES[@]}"; do
    BACKUP_FILE="${BACKUP_DIR}/${VOL_NAME}_${DATE}.tar.gz"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "ERRO: Backup do volume $VOL_NAME não encontrado para a data $DATE"
        exit 1
    fi
done

# Para o container antes da restauração
echo "Parando container AdGuardHome para restauração..."
docker stop adguardhome

# Loop para restaurar cada volume
for i in "${!VOLUMES[@]}"; do
    VOL_PATH="${VOLUMES[$i]}"
    VOL_NAME="${VOLUME_NAMES[$i]}"
    BACKUP_FILE="${BACKUP_DIR}/${VOL_NAME}_${DATE}.tar.gz"

    echo "Restaurando volume $VOL_NAME a partir de $BACKUP_FILE ..."
    tar xzf "$BACKUP_FILE" -C "$VOL_PATH"
done

# Reinicia o container após a restauração
echo "Reiniciando container AdGuardHome..."
docker start adguardhome

echo "Restauração concluída com sucesso!"
