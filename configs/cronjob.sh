#!/bin/bash

## Caminho do script a ser adicionado ao cron.
PATH_SCRIPT="/root/docker_adguardhome/backup_adguard.sh"
CRON_ENTRY="10 0 * * * /bin/bash $PATH_SCRIPT"
CRON_COMMENT="# Backup diário às 00h10 dos volumes bind do container Docker do AdGuard Home"

echo "Adicionando entrada ao crontab do root para backup diário do AdGuardHome..."
## Verificar se a entrada já existe no crontab.
if ! sudo crontab -u root -l 2>/dev/null | grep -Fxq "$CRON_ENTRY"; then
    # Se a entrada não existir, adicione-a com o comentário.
    (sudo crontab -u root -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_ENTRY") | sudo crontab -u root -
fi
echo "Entrada de cron verificada/adicionada com sucesso."