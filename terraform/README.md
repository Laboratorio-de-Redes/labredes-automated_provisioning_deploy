# 🧊 Provisionamento de Infraestrutura (Terraform)

![Terraform](../images/terraform.png)

Este diretório contém os códigos declarativos escritos em HCL (HashiCorp Configuration Language) utilizados para o provisionamento automatizado da infraestrutura no ambiente OpenStack.

O objetivo destes arquivos é definir o estado desejado do hardware virtual (máquinas, discos, chaves SSH e interfaces de rede) e gerar dinamicamente o inventário de instâncias que será consumido posteriormente pelo motor do Ansible. 
O Terraform é responsável por enviar comandos declarativos para a nuvem OpenStack, instruindo-a a criar o hardware virtual.
Instalação do pacotes utilitários obrigatórios:
```
apt install -y gnupg software-properties-common curl
```
**Função do comando:** `gnupg`: permite manipulação e validação de chaves criptográficas;

`software-properties-common`: fornece ferramentas para adicionar repositórios de terceiros ao sistema;

`curl`: é um cliente de transferência de dados via protocolos web (HTTP/HTTPS).

Chave GPG da HashiCorp:
```
curl -fsSL [https://apt.releases.hashicorp.com/gpg](https://apt.releases.hashicorp.com/gpg) | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
```
**Função do comando:** `curl`: faz o download da chave criptográfica pública da HashiCorp (desenvolvedora do Terraform);

`|`: redireciona essa chave baixada diretamente para o comando `gpg --dearmor`;

`gpg --dearmor`: converte o arquivo do formato texto (ASCII) para o formato binário, salvando-o no diretório de chaves de segurança do sistema. Isso garante a autenticidade dos pacotes do Terraform.
```
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] [https://apt.releases.hashicorp.com](https://apt.releases.hashicorp.com) $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
```
**Função do comando:** Constrói uma string contendo a URL do repositório oficial do Terraform e a vincula à chave criptográfica salva anteriormente. O comando `tee` grava essa string em um novo arquivo dentro do diretório de fontes do gerenciador de pacotes apt.

Instalação do Terraform:
```
apt update && apt install -y terraform
```
**Função do comando:** Atualiza os metadados do sistema para incluir os softwares do novo repositório da HashiCorp e, em seguida, baixa e instala o binário compilado do Terraform.

---

## 📋 1. Estrutura de Arquivos

A configuração foi modularizada nos seguintes arquivos para isolamento de contexto:

* `main.tf`: Declaração do provider e autenticação com a API da nuvem.
* `instances.tf`: Lógica de iteração para criação dos recursos computacionais e do inventário local.

---

## 2. Configuração do Provider (`main.tf`)

O arquivo `main.tf` é responsável por inicializar o plugin de comunicação com o OpenStack e definir as rotas de acesso (endpoints) da API REST.
Criar o provider Terraform:
```
nano ~/terraform/labredes/main.tf
```
```hcl
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}
provider "openstack" {
  cloud = "labredes"

  endpoint_overrides = {
    "compute"  = "http://10.10.2.9:8774/v2.1/90f1c80288444ed4bb4e41b5aa2d003f/"
    "network"  = "http://10.10.2.9:9696/v2.0/"
    "image"    = "http://10.10.2.9:9292/v2/"
    "volumev3" = "http://10.10.2.9:8776/v3/90f1c80288444ed4bb4e41b5aa2d003f/"
    "identity" = "http://10.10.2.9:5000/v3/"
  }
}
```

Inicializar o Terraform:
```
cd ~/terraform/labredes
terraform init
```

## 3. Criar uma VM teste:
```
nano ~/terraform/labredes/instances.tf
```
```
resource "openstack_compute_instance_v2" "vm_teste" {
  name            = "vm-teste"
  image_name      = "f7ca5526-1dc7-4207-adff-3178b7c5e581"
  flavor_name     = "minor.pico.large"
  key_pair        = "labredes_key"
  security_groups = ["clear", "default"]

  network {
    name = "labredes1"
  }
}
```
Revisar o que será criado e aplicar:
```
terraform plan
terraform apply -auto-approve
```
Ao final do processo, uma VM será criada com os recursos declarados no `instances.tf`.
Para apagar a instância execute:
```
terraform destroy -auto-approve
```

---

## 3. Mapeamento de Recursos (`variables.tf`)

Para evitar repetição de código, as características das instâncias foram mapeadas em um dicionário de variáveis. O Terraform lê este mapeamento e provisiona as máquinas em lote.

![Ansible](../images/ansible.png)
