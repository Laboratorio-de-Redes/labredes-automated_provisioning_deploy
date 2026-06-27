# ☁️ Instalação e Configuração OpenStack Client (Interface de Linha de Comando da Nuvem)

![OpenStack](images/openstack.png)

Esta ferramenta abstrai as requisições HTTP/REST, permitindo consultar IDs de rede, listar instâncias e inserir chaves SSH na nuvem via linha de comando.
```
apt install -y python3-pip python3-dev
apt install -y python3-openstackclient
```
**Função dos comandos:** O primeiro comando instala o gerenciador de pacotes da linguagem Python (pip) e as bibliotecas de desenvolvimento C/C++ necessárias para a compilação de extensões. O segundo comando utiliza o repositório do Ubuntu para baixar o cliente unificado do OpenStack e suas dependências criptográficas.

---

## 🪪 1. Autenticação com a Nuvem OpenStack

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

## 🔐 2. Geração e Registro de Chaves Criptográficas (SSH)

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
