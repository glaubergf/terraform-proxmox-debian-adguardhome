<!---
# ================================================================
Projeto: terraform-proxmox-debian-adguardhome
---
Descrição: Este projeto cria uma VM do Debian 13 (Trixie) no Proxmox 
utilizando Script, Terraform, Cloud-Init e Docker. Após a criação, o 
AdGuard Home esta pronto para rastrear e bloquear ameaças DNS. 
Adicione o IP do Servidor AdGuard Home no roteador como DNS primário 
para abranger todos os dispositivos conectado ao roteador.
---
Autor: Glauber GF (mcnd2)
Criado: 27-11-2025
Atualizado: 06-12-2025
# ================================================================
--->

# Servidor Debian AdGuard Home (Docker)

![Image](https://github.com/glaubergf/terraform-proxmox-debian-adguardhome/blob/main/images/tf-pm-adguardhome.png)

![Image](https://github.com/glaubergf/terraform-proxmox-debian-adguardhome/blob/main/images/adguardhome.png)

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)

## 📜 Sobre o Projeto

Este projeto provisiona um servidor **Debian 13 (Trixie)** no **Proxmox VE 9.1.2** utilizando **Terraform** e **cloud-init**, com implantação automatizada do **AdGuard Home** em container **Docker**.

## 🪄 O Projeto Realiza

- Download automático da última imagem Debian Generic.
- Criação de Template no Proxmox via QEMU.
- Criação da VM no Proxmox via Terraform.
- Configuração do sistema operacional via Cloud-Init.
- Uploads de arquivos para a VM.
- Instalação e configuração do Docker.
- Desabilitar systemd-resolved na VM.
- Sobe o container AdGuard Home via docker compose.
- Configuar a cron para rodar script de backup.

## 🧩 Tecnologias Utilizadas

![Terraform](https://img.shields.io/badge/Terraform-623CE4?logo=terraform&logoColor=white&style=for-the-badge)
- [Terraform](https://developer.hashicorp.com/terraform) — Provisionamento de infraestrutura como código (IaC).
 ---
![Proxmox](https://img.shields.io/badge/Proxmox-E57000?logo=proxmox&logoColor=white&style=for-the-badge)
- [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) — Hypervisor para virtualização.
---
![Cloud-Init](https://img.shields.io/badge/Cloud--Init-00ADEF?logo=cloud&logoColor=white&style=for-the-badge)
- [Cloud-Init](https://cloudinit.readthedocs.io/en/latest/) — Ferramenta de inicialização e configuração automatizada da VM.
---
![Debian](https://img.shields.io/badge/Debian-A81D33?logo=debian&logoColor=white&style=for-the-badge)
- [Debian](https://www.debian.org/) — Sistema operacional da VM.
---
![Docker](https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white&style=for-the-badge)
- [Docker](https://www.docker.com/) — Containerização da aplicação sysPass.
---
![AdGuard Home](https://img.shields.io/badge/AdGuard%20Home-68BC71?style=for-the-badge&logo=adguard&logoColor=white)
- [AdGuard Home](https://adguard.com/) — Bloqueador de anúncios e rastreadores.

## 💡 Motivação

Automatizar a criação de um ambiente seguro e escalável para uma solução completa de DNS filtering e bloqueio de anúncios, usando como DNS primário na rede.

O AdGuard Home é ideal para:

- Bloquear anúncios e malware em toda a rede
- Melhorar privacidade
- Ter visibilidade completa do tráfego DNS
- Criar regras por dispositivo
- Filtragem segura para crianças
- Rodar com estabilidade em VM ou Docker
- Realizar backup fácil
- Usar HA com keepalived
- Ter controle total sem depender do roteador

## 🛠️ Pré-requisitos

- ✅ Proxmox VE com API habilitada.
- ✅ Usuário no Proxmox com permissão para criação de VMs.
- ✅ Chave SSH pública e privada para acesso à VM.
- ✅ Terraform instalado localmente.

## 📂 Estrutura do Projeto

```
terraform-proxmox-debian-adguardhome
├── configs
│   ├── backup-adguard.sh
│   ├── cloud-config.yml
│   ├── config-motd.sh
│   ├── cronjob.sh
│   ├── disable-systemd-resolved.sh
│   ├── docker-compose.yml
│   ├── motd-adguardhome
│   ├── network-config.yml
│   ├── restore-adguard.sh
│   └── vm-template.sh
├── images
│   ├── adguardhome.png
│   └── tf-pm-adguardhome.png
├── notes
│   ├── art-ascii-to-modt.txt
│   ├── docker-compose.yml.template
│   └── terraform.tfvars.template
├── security
│   ├── AdGuardHome.yaml.rules.Gabriel
│   ├── auth-proxmox.txt
│   ├── tf-proxmox_id_rsa
│   └── tf-proxmox_id_rsa.pub
├── LICENSE
├── output.tf
├── provider.tf
├── README.md
├── terraform.tfvars
├── variables.tf
└── vm-proxmox.tf
```

### 📄 Arquivos

- `provider.tf` → Provedor do Proxmox
- `vm_proxmox.tf` → Criação da VM, configuração da rede, execução dos scripts
- `variables.tf` → Definição de variáveis
- `terraform.tfvars` → Valores das variáveis (customização)
- `cloud_config.yml` → Configurações do Cloud-Init (usuário, pacotes, timezone, scripts)
- `network_config.yml` → Configuração de rede estática
- `docker-compose.yml` → Define e organiza os contêineres Docker

## 🚀 Fluxo de Funcionamento

1. **Terraform Init:** Inicializa o Terraform e carrega os providers e módulos necessários.

2. **Download da imagem Debian Generic:** Script baixa a última imagem Debian pré-configurada (Generic) e salva em um Template no Proxmox.

3. **Criação da VM no Proxmox:** Terraform cria uma VM no Proxmox com base nas variáveis definidas.

4. **Aplicação do Cloud-Init:** Injeta configuração automática na VM (rede, usuário, SSH, hostname, etc.).

5. **Configuração inicial da VM:** A VM é inicializada e aplica configurações básicas (acesso remoto, hostname, rede, etc.).

6. **Preparação da VM:** Upload de arquivos de configurações para a VM, instalação do Docker e Docker Compose na VM, etc.

7. **Deploy dos containers:** O Docker Compose sobe o container do Grafana e do mariaDB.

8. **Pós provisonamento:** Importar (manualmente) o json dos dashboards que foram copiados para o ambiente de acordo com o datasources.

## 🛠️ Terraform

Ferramenta de IaC (Infrastructure as Code) que permite definir e gerenciar infraestrutura através de arquivos de configuração declarativos.

Saiba mais: [https://developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform)

## 🖥️ Proxmox VE

O Proxmox VE é um hipervisor bare-metal, robusto e completo, muito utilizado tanto em ambientes profissionais quanto em homelabs. É uma plataforma de virtualização open-source que permite gerenciar máquinas virtuais e containers de forma eficiente, com suporte a alta disponibilidade, backups, snapshots e uma interface web intuitiva.

Saiba mais: [https://www.proxmox.com/](https://www.proxmox.com/)

## 🐧 Debian

Distribuição Linux livre, estável e robusta. A imagem utilizada é baseada no **Debian Generic**, que rodar em qualquer ambiente usando cloud-init, como por exemplo: OpenStack, DigitalOcean, bare metal etc.

Saiba mais: [https://www.debian.org/](https://www.debian.org/)

#### ☁️ Sobre a imagem Debian Generic

Sabia mais: [https://cdimage.debian.org/cdimage/cloud/](https://cdimage.debian.org/cdimage/cloud/)

## ☁️ Cloud-Init

Ferramenta de provisionamento padrão de instâncias de nuvem. Permite configurar usuários, pacotes, rede, timezone, scripts e mais, tudo automaticamente na criação da VM.

Saiba mais: [https://cloudinit.readthedocs.io/](https://cloudinit.readthedocs.io/)

## 🐳 Docker

Plataforma que permite empacotar, distribuir e executar aplicações em containers de forma leve, portátil e isolada, facilitando a implantação e escalabilidade de serviços.

Saiba mais: [https://www.docker.com](https://www.docker.com)

## 📊 AdGuard Home

O AdGuard Home é um bloqueador de anúncios a nível de sistema. Ele bloqueia anúncios e rastreadores no dispositivo, selecione entre filtros pré-instalados ou adicione os seus próprios, tudo através da interface de linha de comando.

✨ Principais funcionalidades:

- Bloqueio de anúncios
- Proteção de privacidade
- Web segura
- Filtragem personalizável

Saiba mais: [https://adguard.com](https://adguard.com)

## ▶️ Execução do Projeto

1. Clone o repositório:

```bash
git clone https://github.com/glaubergf/terraform-proxmox-debian-adguardhome.git
cd terraform-proxmox-debian-adguardhome
```

2. Edite o arquivo `terraform.tfvars` com suas variáveis.

3. Inicialize o Terraform:

```bash
terraform init
```

4. Execute o plano para mostra o que será criado:

```bash
terraform plan
```

5. Aplique o provisionamento (infraestrutura):

```bash
terraform apply
```

6. Para destruir toda a infraestrutura criada (caso necessário):

```bash
terraform destroy
```

7. Para executar sem confirmação interativa, use:

```bash
terraform apply --auto-approve
terraform destroy --auto-approve
```

## 🤝 Contribuições

Contribuições são bem-vindas!

## 📜 Licença

Este projeto está licenciado sob os termos da **[GNU General Public License v3](https://www.gnu.org/licenses/gpl-3.0.html)**.

### 🏛️ Aviso Legal

```
Copyright (c) 2025

Este programa é software livre: você pode redistribuí-lo e/ou modificá-lo
sob os termos da Licença Pública Geral GNU conforme publicada pela
Free Software Foundation, na versão 3 da Licença.

Este programa é distribuído na esperança de que seja útil,
mas SEM NENHUMA GARANTIA, nem mesmo a garantia implícita de
COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM DETERMINADO FIM.

Veja a Licença Pública Geral GNU para mais detalhes.
```
