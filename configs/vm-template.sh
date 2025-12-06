#!/bin/bash

# ================================================================
# Nome:       vm-template.sh
# Versão:     2.0
# Autor:      Glauber GF (mcnd2)
# Criado:     17/04/2025
# Atualizado: 05/12/2025
#
# Descrição:
#   Esse script cria uma imagem de template atualizada em QCOW2 
#   no servidor Proxmox.
# ================================================================

set -euo pipefail

# === Instalar dependência para manipular imagens QCOW2 ===
# O pacote 'libguestfs-tools' é necessário para o 'virt-customize'
if ! dpkg -l | grep -q libguestfs-tools; then
    apt install libguestfs-tools -y
else
    echo "[✓] libguestfs-tools já está instalado."
fi

# Imagens (https://cloud.debian.org/):
# - generic:      Deve rodar em qualquer ambiente usando cloud-init, por exemplo:
#                 OpenStack, DigitalOcean e também em bare metal.
# - genericcloud: Semelhante ao generic. Deve rodar em qualquer ambiente virtualizado.
#                 É menor que `generic` ao excluir drivers para hardware físico.
# - nocloud:      Mais útil para testar o próprio processo de build.
#                 Não tem cloud-init instalado, mas permite login root sem senha.

# === Variáveis de configuração ===
URL="https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-generic-amd64.qcow2"
#URL="https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
#URL="https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-nocloud-amd64.qcow2"
IMAGE_NAME="debian-13-generic-amd64"
IMAGE_FILE="${IMAGE_NAME}.qcow2"
IMAGE_DIR="/var/lib/vz/template/qemu"
ARCHIVE_DIR="$IMAGE_DIR/archive"
STORAGE="local"
VMID=2000
TEMPLATE_NAME="trixie-generic"
HASH_FILE="${IMAGE_FILE}.sha512"

# === Criar diretório para armazenar imagens antigas compactadas ===
mkdir -p "$ARCHIVE_DIR"

# === Função: Baixar a imagem mais recente e verificar se ela é diferente da atual ===
download_latest_image() {
  echo "[+] Verificando nova versão da imagem..."
  cd "$IMAGE_DIR"
  TMP_IMAGE="latest_temp.qcow2"
  # Arquivo onde o hash sha512 da imagem atual é salvo
  HASH_FILE="${IMAGE_FILE}.sha512"

  # === Baixar a imagem temporária para comparação com tentativas ===
  MAX_RETRIES=3
  RETRY_DELAY=10   #300 = 5 minutos
  attempt=1

  while true; do
      echo "[+] Tentativa $attempt de $MAX_RETRIES para baixar a imagem..."
      wget -q -O "$TMP_IMAGE" "$URL"

      # Se arquivo baixou com sucesso (tamanho > 0), sai do loop
      if [ -s "$TMP_IMAGE" ]; then
          echo "[✓] Download concluído com sucesso."
          break
      fi

      # Se chegou no máximo de tentativas, falha de verdade
      if [ $attempt -ge $MAX_RETRIES ]; then
          echo "[ERRO] Falha ao baixar a imagem após $MAX_RETRIES tentativas."
          rm -f "$TMP_IMAGE"
          exit 1
      fi

      echo "[!] Falha ao baixar a imagem. Tentando novamente em 10 segundos..."
      rm -f "$TMP_IMAGE"  # limpa arquivo corrompido
      sleep $RETRY_DELAY
      attempt=$((attempt + 1))
  done
 
  # === Se já houver imagem existente, comparar os hashes ===
  if [ -f "$IMAGE_FILE" ]; then
    # Calcula o hash da imagem nova
    TMP_HASH=$(sha512sum "$TMP_IMAGE" | awk '{print $1}')

    # Verifica se há hash antigo salvo
    if [ -f "$HASH_FILE" ]; then
      OLD_HASH=$(cat "$HASH_FILE")

      if [ "$TMP_HASH" == "$OLD_HASH" ]; then
        echo "[✓] A imagem atual já está atualizada (hash sha512 idêntico)."
        rm "$TMP_IMAGE"
        return 1  # Nenhuma ação necessária
      else
        echo "[!] Imagem nova detectada via hash. Arquivando a imagem atual..."
        TIMESTAMP=$(date +%Y%m%d-%H%M%S)
        gzip -c "$IMAGE_FILE" > "$ARCHIVE_DIR/${IMAGE_FILE}.${TIMESTAMP}.gz"
        rm "$IMAGE_FILE"
      fi
    else
      echo "[!] Hash anterior não encontrado. Tratando como nova imagem."
      gzip -c "$IMAGE_FILE" > "$ARCHIVE_DIR/${IMAGE_FILE}.nohash.gz"
      rm "$IMAGE_FILE"
    fi
  fi

  # === Salvar nova imagem e gerar novo hash ===
  mv "$TMP_IMAGE" "$IMAGE_FILE"
  TMP_HASH=$(sha512sum "$IMAGE_FILE" | awk '{print $1}')
  echo "$TMP_HASH" > "$HASH_FILE"

  echo "[+] Nova imagem baixada e hash registrado para futuras comparações."
  return 0
}

# === Função: Remover template existente com seu disco ===
remove_old_template() {
  if qm list | grep -q "$TEMPLATE_NAME"; then
    echo "[!] Template existente encontrado. Removendo..."
    qm destroy $VMID --purge || true
  else
    echo "[✓] Nenhum template anterior encontrado."
  fi
}

# === Função: Criar o novo template atualizado ===
create_template() {
  echo "[+] Personalizando imagem..."

  # Instalar pacotes e configurar o qemu-guest-agent
  #virt-customize -a "$IMAGE_FILE" \
    #--install qemu-guest-agent \
    #--run-command 'systemctl enable qemu-guest-agent' \
    #--run-command 'systemctl start qemu-guest-agent' \
    #--truncate /etc/machine-id

  virt-customize -a "$IMAGE_FILE" \
    --truncate /etc/machine-id

  sleep 15;

  echo "[+] Criando nova VM no Proxmox..."
  qm create $VMID -name $TEMPLATE_NAME -memory 1024 -cores 1 -sockets 1 -net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci

  echo "[+] Importando disco para o storage do Proxmox..."
  qm importdisk $VMID "$IMAGE_DIR/$IMAGE_FILE" $STORAGE

  # === Anexar o disco à VM ===
  qm set $VMID -scsihw virtio-scsi-pci -scsi0 $STORAGE:$VMID/vm-$VMID-disk-0.raw

  # Configurações adicionais da VM
  qm set $VMID -boot c -bootdisk scsi0    # Definir disco de boot
  qm set $VMID -agent 1                   # Habilitar QEMU guest agent
  qm set $VMID -hotplug disk,network,usb  # Permitir hotplug
  qm set $VMID -vcpus 1                   # Adicionar vCPU
  qm set $VMID -vga virtio                # Definir saída de vídeo
  qm set $VMID -ide2 $STORAGE:cloudinit   # Adicionar disco de cloud-init

  # Aumentar o tamanho do disco principal
  qm disk resize $VMID scsi0 +4G

  # Converter a VM em template
  echo "[+] Convertendo para template..."
  qm template $VMID

  echo "[✓] Template atualizado com sucesso!"
}

# === Execução principal ===
if download_latest_image; then
    # → imagem mudou, recria template
    remove_old_template
    create_template
else
    # → imagem não mudou, verificar se template existe
    if qm list | grep -q "^\s*$VMID\s"; then
        echo "[✓] Template já existe e está atualizado."
    else
        echo "[!] Hash igual, mas o template NÃO existe! Criando template..."
        create_template
    fi
fi
echo "[✓] Processo concluído."
