cat << 'EOF' > README.md
# 🌐 LabRedes - Automated Provisioning & Deploy (IaC)

Este repositório contém o código-fonte para o provisionamento e configuração automatizada da infraestrutura do **LabRedes**. Utilizando os paradigmas de *Infrastructure as Code* (IaC) e *Configuration Management*, o projeto constrói um ambiente complexo de redes virtualizadas no OpenStack, englobando roteamento inter-VLAN, switches Open vSwitch (OVS), servidores de autenticação centralizada, bancos de dados, motores de análise de tráfego e dashboards.

---

## 📂 Estrutura de Diretórios

O projeto está encapsulado no diretório `auto_deploy/`, subdividido nas seguintes responsabilidades:

```
auto_deploy/
├── criar-redes-teste.sh      # Script de topologia L2 (Neutron/OpenStack)
├── terraform/                # Provisionamento de instâncias (Compute)
│   ├── main.tf               # Configurações do provedor OpenStack
│   └── instances.tf          # Definição das VMs, Flavors, Keypairs e Redes
└── ansible/                  # Orquestração e Configuração de SO/Aplicações
    ├── ansible.cfg           # Ajustes de comportamento do Ansible
    ├── hosts.ini             # Inventário dinâmico/estático de IPs
    ├── site.yml              # Playbook mestre (Orquestrador)
    ├── files/                # Arquivos estáticos injetados nas VMs
    └── playbooks/            # Playbooks individuais de cada Nó/VM
``` 

---

## 🛠️ Fase 1: Fundação de Rede (Shell Script)

### `criar-redes-teste.sh`
**Função:** Criar a base de redes e sub-redes (Camada 2 / Camada 3) no OpenStack.
**O Problema que Resolve:** No ambiente do laboratório, as redes de produção (bloco `10.0.x.x`) são compartilhadas entre projetos. Se o ambiente de teste usasse os mesmos nomes de VLAN, haveria colisão de domínio de broadcast e IP.
**A Solução:** O script cria uma **topologia paralela e isolada**. Ele gera 15 redes sufixadas com `-teste` utilizando o bloco IP `10.99.x.x`. 
**Detalhes de Execução:** * As redes são criadas *sem DHCP* e *sem Gateway* nativo do OpenStack, forçando o tráfego a ser roteado pelos nossos próprios Firewalls e roteadores (VM11).
* **Como rodar:** `chmod +x criar-redes-teste.sh && ./criar-redes-teste.sh`

---

## 🏗️ Fase 2: Provisionamento Computacional (Terraform)

O diretório `terraform/` é responsável por conversar com a API do OpenStack para solicitar a criação do hardware virtual.

* **`main.tf`**: Define o provedor (Terraform OpenStack Provider). Contém as credenciais ou aponta para as variáveis de ambiente (`clouds.yaml`) necessárias para autenticação no tenant correto.
* **`instances.tf`**: O coração do provisionamento. Aqui estão mapeadas as 13 máquinas virtuais. Ele define o sistema operacional (Ubuntu 24.04), a quantidade de vCPUs/RAM (Flavors), as chaves SSH de acesso e, o mais importante, **conecta cada VM às portas de rede específicas** criadas pelo script anterior. Por exemplo, garante que o Firewall tenha "pernas" em várias VLANs, enquanto os usuários normais tenham apenas uma.

---

## ⚙️ Fase 3: Configuração e Gerência de Estado (Ansible)

Uma vez que o Terraform entrega as VMs "cruas", o Ansible assume para transformá-las em servidores funcionais e roteadores.

### Arquivos Base do Ansible
* **`ansible.cfg`**: Desativa checagens estritas de chaves SSH (necessário em ambientes de nuvem efêmeros) e ajusta timeouts para lidar com lentidões de rede.
* **`hosts.ini`**: O inventário. Mapeia os nomes lógicos (ex: `[VM1]`) para os IPs de gerência (`192.168.10.x`) fornecidos pelo OpenStack. É através destes IPs que o Ansible injeta as configurações via SSH.
* **`site.yml`**: O playbook orquestrador. Ele não executa tarefas diretamente, mas faz os `imports` na ordem exata de dependência. Ele dita: *"Configure primeiro os Switches, depois o Firewall, depois o Banco de Dados, e só no final o Dashboard"*.
* **`files/`**: Um diretório vital. Contém arquivos `.env`, `docker-compose.yml`, scripts SQL e `.ldif` (LDAP). **Por que é necessário?** Para garantir a integridade. Injetar configurações complexas via linha de comando (`sed`/`echo`) corrompe arquivos YAML com erros invisíveis de indentação. O Ansible usa o módulo `copy` para transferir arquivos perfeitos e testados localmente direto para as VMs.

---

## 🧠 Arquitetura dos Playbooks: A Função de Cada VM

O diretório `playbooks/` contém o código de provisionamento detalhado de cada nó da rede. Abaixo está a função de cada máquina e o que o seu playbook executa:

### 🌐 Infraestrutura de Core L2/L3
* **`SW1` e `SW2` (Switches Virtuais Core)**
  * **Função:** Atuar como o backbone da rede local.
  * **Ações do Playbook:** Instala o **Open vSwitch (OVS)**. Cria a bridge `br-int`. Configura portas *Trunk* (que passam as VLANs 10, 20, 30, 40, 50 e 60 simultaneamente) e portas *Access* (que adicionam as tags de VLAN para as VMs finais). No final, injeta fluxos OpenFlow para habilitar o **Port Mirroring (SPAN)**, espelhando todo o tráfego da rede e enviando uma cópia exata para a máquina de captura (VM4).
* **`VM11` (Firewall e Roteador Inter-VLAN)**
  * **Função:** É o "cérebro" do roteamento L3. Controla quem fala com quem.
  * **Ações do Playbook:** Habilita o *IP Forwarding* no kernel do Linux. Instala e configura regras estritas de **Nftables**. Restringe tamanhos de logs do `journald` para não estourar o disco e sobe os containers responsáveis pelo monitoramento e bloqueio de pacotes.

### 🔐 Autenticação e Dados
* **`VM9` (Servidor LDAP)**
  * **Função:** Prover Single Sign-On (SSO) e diretório de usuários unificado para todas as aplicações do laboratório.
  * **Ações do Playbook:** Sobe containers do OpenLDAP e phpLDAPadmin. O playbook verifica se a base de dados existe; se não, ele injeta os arquivos estáticos `estrutura.ldif`, `grupos.ldif` e `usuarios.ldif` (da pasta `files/`), criando as Unidades Organizacionais (OUs) e usuários base (Admin, Aluno1, Aluno2).
* **`VM1` (Servidor Central / Banco de Dados)**
  * **Função:** Hospedar o PostgreSQL e a API central que alimenta os dashboards.
  * **Ações do Playbook:** Prepara os diretórios, injeta variáveis de ambiente (`POSTGRES_USER`, etc.) e o IP dinâmico da VM9 (LDAP). Sobe o container e possui lógica avançada de *Healthcheck* (`docker inspect`) para só liberar a continuidade do deploy quando o banco de dados reportar o status `healthy`.

### 📊 Observabilidade e Monitoramento
* **`VM2` (Dashboard WEB)**
  * **Função:** Interface visual para os usuários interagirem com os dados do laboratório.
  * **Ações do Playbook:** Faz o clone (`git clone`) do repositório da aplicação (Frontend React e Backend Python). Copia um `docker-compose.yml` limpo da pasta `files/` com os IPs corretos do LDAP, realiza o *build* das imagens localmente na VM e inicia os containers, incluindo o Grafana.
* **`VM3` (Descoberta de Hosts)**
  * **Função:** Mapear ativos conectados à rede e gerar topologia.
  * **Ações do Playbook:** Ajusta o Netplan e sobe o container garantindo elevação de privilégio (`privileged: true` e `network_mode: host`) para permitir que a aplicação execute escaneamentos de pacotes L2 na interface física da máquina.
* **`VM4` (Captura de Tráfego)**
  * **Função:** Receber o tráfego espelhado (SPAN) dos switches SW1 e SW2.
  * **Ações do Playbook:** É um script complexo de rede. Coloca as interfaces L2 em **modo promíscuo** (permitindo leitura de pacotes alheios). Cria subinterfaces `.1Q` (`ens4.10`, `ens4.20`, etc.) atreladas às VLANs e inicializa o container de geração/captura de fluxos (Flow Generator).
* **`VM6` (Motor Analítico)**
  * **Função:** Processar os pacotes crus (PCAPs) gerados pela VM4 em matrizes de tráfego estruturadas.
  * **Ações do Playbook:** Sobe a stack analítica e testa endpoints de saúde (`/health`) e de matriz matemática ao final do deploy para garantir a integridade do processamento de dados.
* **`VM7` (Sistema de Alertas)**
  * **Função:** Disparar notificações quando métricas anômalas são detectadas na rede.
  * **Ações do Playbook:** Baixa e compila o projeto web. Tem o Netplan injetado estrategicamente *após* o download dos containers (para evitar perda de rota de internet L3) e mapeia as portas HTTP de saída de alertas.

### 💻 Clientes / Endpoints de Teste
* **`VM_USER1`, `VM_USER2` e `VM_DEV`**
  * **Função:** Simular máquinas físicas de usuários normais ou desenvolvedores em diferentes VLANs. Servem para testes de ping, bloqueio de firewall inter-VLAN e geração de tráfego.
  * **Ações dos Playbooks:** Configurações muito enxutas. Aplicam o IP fixo via Netplan nas VLANs designadas. Possuem uma tratativa especial para **não injetar rotas default (gateway)** que possam sobrescrever a placa de gerência, evitando asfixia do SSH (corte da conexão do Ansible) durante o roteamento assimétrico.

---
*Este repositório garante a reprodutibilidade da infraestrutura. A nuvem pode ser destruída e recriada do zero com o apertar de um botão.*
EOF
