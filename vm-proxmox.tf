# Origem do arquivo de configuração do Cloud Init.
data "template_file" "cloud_init" {
  template = file(var.cloud_config_file)

  vars = {
    ssh_key  = file(var.ssh_key)
    hostname = var.vm_hostname
    domain   = var.vm_domain
    password = var.vm_password
    user     = var.vm_user
  }
}

data "template_file" "network_config" {
  template = file(var.network_config_file)
}

# Criar uma cópia local dos arquivos para transferir para o servidor Proxmox.
resource "local_file" "cloud_init" {
  content  = data.template_file.cloud_init.rendered
  filename = "${path.module}/configs/adguardhome-cloud-init.cfg"
}

resource "local_file" "network_config" {
  content  = data.template_file.network_config.rendered
  filename = "${path.module}/configs/adguardhome-network-config.cfg"
}

# Transferir os arquivos para o servidor Proxmox.
resource "null_resource" "cloud_init" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key)
    host        = var.srv_proxmox
  }

  provisioner "file" {
    source      = local_file.cloud_init.filename
    destination = "/var/lib/vz/snippets/adguardhome-cloud-init.yml"
  }

  provisioner "file" {
    source      = local_file.network_config.filename
    destination = "/var/lib/vz/snippets/adguardhome-network-config.yml"
  }
}

# Copiar o script de template para o servidor Proxmox e executá-lo.
resource "null_resource" "proxmox_template_script" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key)
    host        = var.srv_proxmox
  }

  # Copiar o script para o Proxmox.
  provisioner "file" {
    source      = var.vm_template_script_path
    destination = "/tmp/vm-template.sh"
  }

  # Executar o script no Proxmox.
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/vm-template.sh",
      "bash /tmp/vm-template.sh"
    ]
  }
}

# Criar a VM, depende da execução do script no Proxmox.
resource "proxmox_vm_qemu" "debian_generic" {
  depends_on = [
    null_resource.proxmox_template_script,
    null_resource.cloud_init
  ]

  name        = var.vm
  target_node = var.node

  # Clonar o modelo 'cloudinit'.
  clone   = var.template
  os_type = "cloud-init"

  # Opções do Cloud Init
  cicustom = "user=${var.storage_proxmox}:snippets/adguardhome-cloud-init.yml,network=${var.storage_proxmox}:snippets/adguardhome-network-config.yml"

  # Configurações de hardware.
  vmid = var.vm_vmid
  cpu {
    cores = var.vm_cores
  }
  memory             = var.vm_memory
  agent              = 1
  kvm                = true
  start_at_node_boot = true

  # Definir os parâmetros do disco de inicialização bootdisk = "scsi0".
  scsihw = "virtio-scsi-pci" # virtio-scsi-single

  # Configurar disco principal
  disk {
    slot     = "scsi0"
    type     = "disk"
    format   = "raw"
    iothread = true
    storage  = var.storage_proxmox
    size     = var.disk_size
  }

  # Configurar drive do CloudInit.
  disk {
    type    = "cloudinit"
    slot    = "scsi1" #"ide2"
    storage = var.storage_proxmox
  }

  # Ordem de boot.
  boot = "order=scsi0;scsi1" #ide2

  # Adicionar configuração de BIOS (UEFI 'ovmf' / BIOS tradicional 'seabios').
  bios = "seabios"

  # Aumentar o tempo de espera para o agente QEMU, se necessário.
  agent_timeout = 300

  # Desabilitar a verificação de IPv6.
  skip_ipv6 = true

  # Configurar rede da VM.
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    macaddr = var.vm_macaddr
  }

  # Ignorar alterações nos atributos dos recursos.
  lifecycle {
    ignore_changes = [
      cicustom,
      sshkeys,
      network
    ]
  }
}

## Provisionar as configurações dentro da VM após criada.
# Envio de arquivos para a VM
resource "null_resource" "upload_files" {
  depends_on = [proxmox_vm_qemu.debian_generic]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "file" {
    source      = var.config_motd_script_path
    destination = "/tmp/config-motd.sh"
  }

  provisioner "file" {
    source      = var.motd_adguardhome_path
    destination = "/tmp/motd-adguardhome"
  }

  provisioner "file" {
    source      = var.docker_compose_path
    destination = "/tmp/docker-compose.yml"
  }

  provisioner "file" {
    source      = var.disable_systemd_resolved_path
    destination = "/tmp/disable-systemd-resolved.sh"
  }
  provisioner "file" {
    source      = var.backup_adguard_path
    destination = "/tmp/backup_adguard.sh"
  }

  provisioner "file" {
    source      = var.cronjob_path
    destination = "/tmp/cronjob.sh"
  }

  provisioner "file" {
    source      = var.restore_adguard_path
    destination = "/tmp/restore_adguard.sh"
  }
}

# Instalação do Docker e zabbix-agent2 na VM
resource "null_resource" "install_docker" {
  depends_on = [null_resource.upload_files]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      # Instala Docker caso não exista
      "if ! command -v docker >/dev/null 2>&1; then",
      "  sudo apt update",
      "  sudo apt install -y ca-certificates curl gnupg lsb-release",

      # Diretório de keyrings
      "  sudo install -m 0755 -d /etc/apt/keyrings",

      # Baixa a chave GPG do Docker
      "  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "  sudo chmod a+r /etc/apt/keyrings/docker.gpg",

      # Cria o docker.sources (novo formato DEB822)
      "  sudo sh -c 'cat > /etc/apt/sources.list.d/docker.sources << \"EOF\"\nTypes: deb\nURIs: https://download.docker.com/linux/debian\nSuites: trixie\nComponents: stable\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/docker.gpg\nEOF'",

      "  sudo apt update",
      "  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "  sudo systemctl enable docker",
      "  sudo systemctl start docker",
      "else",
      "  echo 'Docker já está instalado.'",
      "fi",

      # Instala Zabbix Agent 2 caso necessário
      "if ! command -v zabbix_agent2 >/dev/null 2>&1; then",
      "  sudo apt install -y zabbix-agent2",
      "  sudo systemctl enable zabbix-agent2",
      "  sudo systemctl start zabbix-agent2",
      "else",
      "  echo 'Zabbix Agent 2 já está instalado.'",
      "fi",

      # Adiciona usuário zabbix ao grupo docker
      "sudo usermod -aG docker zabbix"
    ]
  }
}

# Organização dos arquivos na VM e execução do script MOTD
resource "null_resource" "prepare_environment" {
  depends_on = [null_resource.install_docker]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /root/docker_adguardhome",
      "sudo mv /tmp/docker-compose.yml /root/docker_adguardhome/docker-compose.yml",

      # Executar script MOTD
      "sudo chmod +x /tmp/config-motd.sh",
      "sudo bash /tmp/config-motd.sh"
    ]
  }
}

# Desabilitar systemd-resolved na VM
resource "null_resource" "disable_systemd_resolved" {
  depends_on = [null_resource.prepare_environment]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/disable-systemd-resolved.sh",
      "sudo bash /tmp/disable-systemd-resolved.sh"
    ]
  }
}

# Subir containers Docker
resource "null_resource" "docker_up" {
  depends_on = [
    null_resource.prepare_environment,
    null_resource.disable_systemd_resolved
  ]

  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo docker compose -f /root/docker_adguardhome/docker-compose.yml up -d",
      "echo 'Container iniciado. Acesse o AdGuard Home em http://${var.vm_ip}'"
    ]
  }
}

# Configurar Backup automático do AdGuard Home via cronjob
resource "null_resource" "configure_cronjob" {
  depends_on = [null_resource.docker_up]
  connection {
    type        = "ssh"
    user        = var.vm_user
    private_key = file(var.private_key)
    host        = var.vm_ip
    timeout     = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/backup_adguard.sh",
      "sudo chmod +x /tmp/cronjob.sh",
      "sudo chmod +x /tmp/restore_adguard.sh",
      "sudo mv /tmp/backup_adguard.sh /root/docker_adguardhome/backup_adguard.sh",
      "sudo mv /tmp/restore_adguard.sh /root/docker_adguardhome/restore_adguard.sh",
      "sudo chown -R root:root /root/docker_adguardhome/",
      "sudo bash /tmp/cronjob.sh"
    ]
  }
}