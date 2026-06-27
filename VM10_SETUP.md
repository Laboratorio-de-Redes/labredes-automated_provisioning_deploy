# 🖥️ Configuração da VM Orquestradora (VM10)

Este documento detalha o processo de inicialização e preparação do sistema operacional Ubuntu 24.04 LTS na máquina VM10 (Deploy Automatizado).

O objetivo desta fase é estabelecer a conectividade de rede com o ambiente de provisionamento e instalar os binários necessários (OpenStack CLI, Terraform, Ansible e Docker) para que a VM10 atue como o nó controlador de toda a infraestrutura.

---

## 🔗 1. Configuração das Interfaces de Rede

A VM10 foi provisionada com duas interfaces de rede físicas virtuais:

* `ens3`: Conectada à rede de gerência (labredes1), recebendo endereçamento via DHCP.
* `ens7`: Conectada à rede interna de provisionamento (VLAN10_DEPLOY), exigindo configuração de IP estático.

### 1.1. Ativação Temporária em Memória

Para estabelecer acesso imediato à rede interna de deploy, os seguintes comandos foram enviados diretamente ao kernel do sistema operacional:

```
ip link set ens7 up
```
**Função do comando:** Altera o estado administrativo da interface de rede ens7 de "DOWN" para "UP".
Isso instrui o kernel do Linux a ativar a placa de rede para o envio e recebimento de quadros ethernet na Camada 2.


```
ip addr add 10.0.110.8/24 dev ens7
```
**Função do comando:** Vincula o endereço IPv4 estático `10.0.110.8`, com a máscara de sub-rede `/24 (255.255.255.0)`, à interface `ens7`.
Esta configuração ocorre na memória volátil e permite o roteamento imediato de pacotes IP, mas não sobrevive a uma reinicialização do sistema.

### 1.2. Configuração de Persistência (Netplan)

Para tornar a configuração de rede permanente, o utilitário padrão do Ubuntu (Netplan) foi utilizado. O arquivo de configuração de rede foi editado com as diretivas estruturais.

Abra o arquivo de configuração:
```
nano /etc/netplan/50-cloud-init.yaml
```

Insira a seguinte estrutura de dados:
```
network:
  version: 2
  ethernets:
    ens3:
      match:
        macaddress: "mac da sua vm correposndente a interface ens3"
      dhcp4: true
      set-name: "ens3"
      mtu: 1450

    ens7:
      match:
        macaddress: "mac da sua vm correposndente a interface ens7"
      addresses:
        - 10.0.110.8/24
      dhcp4: true
      set-name: "ens7"
      mtu: 1450
```


Aplique as configurações:
```
netplan apply
```
**Função do comando:** O utilitário lê a estrutura de dados declarada no arquivo YAML, compila as informações e aplica o estado desejado ao renderizador de rede do sistema (neste caso, o systemd-networkd). Isso regrava as tabelas de roteamento e endereçamento de forma definitiva no disco.

---

## ⚙️ 2. Atualização do Sistema Base

Antes de proceder com a instalação de novos softwares, os pacotes do sistema operacional foram atualizados para garantir estabilidade e segurança.
```
apt update && apt upgrade -y
```

**Função do comando:** `apt update`: Consulta os servidores remotos configurados no sistema e atualiza a lista local de metadados de softwares disponíveis.

`apt upgrade -y`: Compara as versões dos softwares instalados localmente com a lista de metadados atualizada. Realiza o download e a substituição dos binários desatualizados.

`-y`: suprime os prompts de confirmação, aprovando automaticamente as substituições.

---

## 🐳 3. Instalação do Docker (Motor de Contêineres)

![Docker](images/docker.png)

O Docker é necessário para criar, isolar e executar serviços empacotados em ambientes controlados.
```
curl -fsSL [https://get.docker.com](https://get.docker.com) | sudo sh
```

**Função do comando:** `curl`: faz o download do script oficial de instalação automatizada do Docker;

`| sudo sh`: executa esse script com privilégios de superusuário. O script encarrega-se de adicionar os repositórios do Docker, baixar os binários do daemon (dockerd) e do cliente CLI (docker), e iniciar o serviço em segundo plano.
```
sudo usermod -aG docker $USER
```
**Função do comando:** Modifica as propriedades do usuário atual logado no sistema (`$USER`), anexando-o (`-aG`) ao grupo de segurança denominado docker. Isso concede ao usuário a permissão de leitura e escrita no soquete do sistema (`/var/run/docker.sock`), permitindo executar comandos do Docker sem a necessidade de prefixá-los com sudo.

---

## ☁️ 4. Instalação do OpenStack Client (Interface de Linha de Comando da Nuvem)

Esta ferramenta abstrai as requisições HTTP/REST, permitindo consultar IDs de rede, listar instâncias e inserir chaves SSH na nuvem via linha de comando.
```
apt install -y python3-pip python3-dev
apt install -y python3-openstackclient
```
**Função dos comandos:** O primeiro comando instala o gerenciador de pacotes da linguagem Python (pip) e as bibliotecas de desenvolvimento C/C++ necessárias para a compilação de extensões. O segundo comando utiliza o repositório do Ubuntu para baixar o cliente unificado do OpenStack e suas dependências criptográficas.

---

## 🪪 5. Autenticação com a Nuvem OpenStack

Para que o Terraform e o CLI do OpenStack obtenham autorização para provisionar recursos, as credenciais da API foram centralizadas em um arquivo estruturado de configuração.

Crie os diretórios e o arquivo:
```
mkdir -p ~/.config/openstack
nano ~/.config/openstack/clouds.yaml
```

**Função dos comandos:** `mkdir -p`: cria a estrutura de diretórios ocultos no diretório home do usuário logado;

`nano`: abre o editor de texto para a criação do arquivo `clouds.yaml`.

Insira o dicionário de autenticação:
```
clouds:
  labredes:
    auth:
      auth_url: http://10.10.2.9:5000/v3/
      username: "aluno6"
      password: "aluno6"
      project_id: "90f1c80288444ed4bb4e41b5aa2d003f"
      project_name: "labredes"
      user_domain_name: "Default"
      project_domain_id: "default"
    region_name: "RegionOne"
    interface: "public"
    identity_api_version: 3
    compute_endpoint_override: "http://10.10.2.9:8774/v2.1/90f1c80288444ed4bb4e41b5aa2d003f"
    image_endpoint_override: "http://10.10.2.9:9292"
    network_endpoint_override: "http://10.10.2.9:9696"
    volume_endpoint_override: "http://10.10.2.9:8776"
```

**Estrutura do arquivo:** Este arquivo em formato YAML armazena as credenciais de autenticação (usuário, senha, IDs de projeto). As chaves terminadas em `_endpoint_override` instruem explicitamente as ferramentas a enviarem as requisições REST para URLs estáticas (Nova, Glance, Neutron e Cinder), otimizando a comunicação e prevenindo falhas no serviço de descoberta (discovery) do OpenStack.

Aplique a variável de ambiente:
```
export OS_CLOUD=labredes
```

**Função do comando:** Declara uma variável de ambiente na sessão atual do terminal. O Terraform e o OpenStack Client leem esta variável em tempo de execução e buscam o bloco de dados nomeado labredes dentro do arquivo `clouds.yaml` para assinar digitalmente suas requisições HTTP à nuvem.

---

## 🔐 6. Geração e Registro de Chaves Criptográficas (SSH)

Para garantir acesso de gerência às máquinas virtuais criadas sem a necessidade de inserção manual de senhas, um par de chaves de acesso seguro (SSH) foi gerado na VM10 e registrado na nuvem.
```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/labredes_key -N ""
```

**Função do comando:** `ssh-keygen`: Invoca o gerador de chaves criptográficas do sistema.

`-t rsa`: Seleciona o algoritmo matemático base (RSA).

`-b 4096`: Define o tamanho do bloco criptográfico (4096 bits), aumentando a complexidade da chave.

`-f ~/.ssh/labredes_key`: Especifica o caminho de destino e o nome dos arquivos gerados (a chave privada labredes_key e a pública labredes_key.pub).

`-N ""`: Define a ausência (string vazia) de uma frase-senha secundária para a chave privada. Isso é mandatório para que ferramentas de automação como o Ansible consigam ler a chave e realizar conexões em lote sem exigir interrupção humana.

```
openstack keypair create --public-key ~/.ssh/labredes_key.pub labredes_key
```

**Função do comando:** O utilitário do OpenStack lê o conteúdo em texto plano do arquivo da chave pública (`.pub`) e realiza uma requisição POST à API de Computação (Nova) da nuvem. O OpenStack armazena essa chave pública em seu banco de dados sob o identificador lógico `labredes_key`. Durante o provisionamento das novas instâncias pelo Terraform, a nuvem injeta o conteúdo desta chave pública dentro do sistema operacional das novas VMs, autorizando conexões oriundas exclusivamente de quem possuir a chave privada (A VM10).

Confirmação da criação da chave pública:
```
openstack keypair list
```

---
## 💡 Comandos Úteis do OpenStack Client

**🛠 Comandos de Identidade e Autenticação**
* `openstack service list`: Lista todos os serviços registrados no catálogo do Keystone (Identidade).

* `openstack endpoint list`: Exibe as URLs de serviço (endpoints) onde as APIs de computação, rede e volumes estão respondendo.

**💻 Comandos de Computação (Nova)**
* `openstack server list`: Lista todas as instâncias (VMs) provisionadas no projeto, mostrando nomes, status e endereços IP.

* `openstack server show <nome_da_vm>`: Exibe detalhes técnicos de uma máquina virtual específica, como o flavor, os dispositivos de rede atrelados e a imagem de origem.

* `openstack flavor list`: Lista os tipos de hardware (vCPU, RAM, Disco) disponíveis para criação de instâncias.

* `openstack keypair list`: Lista todas as chaves SSH registradas no projeto que estão disponíveis para serem injetadas nas VMs.

**🌐 Comandos de Rede (Neutron)**
* `openstack network list`: Lista todas as redes lógicas (VLANs e redes de gerência) criadas no ambiente.

* `openstack port list`: Exibe todas as portas virtuais conectadas ao barramento do OpenStack, incluindo os endereços MAC associados.

* `openstack security group list`: Lista os grupos de segurança (Firewalls virtuais) que regem as políticas de entrada e saída das VMs.

**📦 Comandos de Imagens e Volumes (Glance/Cinder)**
* `openstack image list`: Lista as imagens de sistemas operacionais (ex: Ubuntu 24.04 LTS) disponíveis para o deploy das VMs.

* `openstack volume list`: Exibe os volumes de armazenamento (discos rígidos virtuais) provisionados.
