# =============================================================================
# instances.tf-teste — Criação de todas as VMs no PROJETO DE TESTE ISOLADO
#
# Diferenças em relação ao instances.tf de produção:
#   1. Todas as redes internas usam sufixo "-teste" (criadas por
#      criar-redes-teste.sh), evitando qualquer colisão com produção.
#   2. VM1 e VM6 apontam para a MESMA rede (VLAN20_SERVER-teste), pois na
#      topologia real de produção ambas compartilham a mesma VLAN física
#      (tag 802.1Q "20" no switch SW2).
#   3. "labredes1" NÃO leva sufixo — é uma rede compartilhada do domínio,
#      já disponível em qualquer projeto, inclusive o de teste.
#   4. rede_extra agora é uma LISTA (não mais uma string única), pois SW1,
#      SW2 e VM11 precisam de múltiplas interfaces extras para reproduzir
#      fielmente os trunks reais: TRUNK_INTER_SW (liga SW1<->SW2) e
#      FIREWALL_1/FIREWALL_2 (ligam SW1/SW2 <-> VM11).
#   5. VM_DEV, VM_USER1, VM_USER2 incluídas para completar as portas access
#      dos switches (SW1: VM_DEV, VM_USER1 | SW2: VM_USER2).
#   6. A porta ens3 do SW2 (que em produção liga à VM10) fica DE FORA desta
#      topologia de propósito — a VM10 nunca é criada via Terraform (nó
#      controlador, não pode depender de si mesmo para ser recriado). Você
#      conectará uma VM10-teste manualmente mais tarde, para outro fim.
#
# PRÉ-REQUISITOS:
#   - Rodar scripts/criar-redes-teste.sh ANTES deste apply (cria as VLANs)
#   - Além disso, PRECISA EXISTIR uma rede "TRUNK_INTER_SW-teste" e
#     "FIREWALL_1-teste" / "FIREWALL_2-teste" — já cobertas pelo script.
#   - clouds.yaml com a entrada "labredes-teste" configurada corretamente
# =============================================================================

variable "vms_projeto" {
  description = "Mapa de VMs do projeto de TESTE com suas redes"
  type = map(object({
    nome        = string
    flavor_name = string
    rede        = string
    rede_extra  = list(string)
  }))

  default = {
    sw1 = {
      nome        = "SW1"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      # Réplica fiel de produção (9 interfaces): FIREWALL_1, TRUNK_INTER_SW,
      # CAP.TRAF1(VM4-espelhamento), AUTENTICACAO(VM9), DESCOB.HOSTS(VM3),
      # DEV(VM_DEV), USER(VM_USER1), CAPT_TRAFE(VM4-gerência, 2ª perna)
      rede_extra  = [
        "FIREWALL_1-teste",
        "TRUNK_INTER_SW-teste",
        "VLAN40_CAP.TRAF1-teste",
        "VLAN10_AUTENTICACAO-teste",
        "VLAN40_DESCOB.HOSTS-teste",
        "VLAN50_DEV-teste",
        "VLAN60_USER-teste",
        "VLAN40_CAPT_TRAFE-teste",
      ]
    }
    sw2 = {
      nome        = "SW2"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      # ens10=FIREWALL_2 | ens15=TRUNK_INTER_SW | ens7=CAP.TRAF2(VM4) |
      # ens4/ens5=VM6/VM1(mesma VLAN20) | ens6=VM2 | ens8=VM7 | ens9=VM_USER2
      # NOTA: ens3 (VM10 em produção) fica DE FORA de propósito.
      rede_extra  = [
        "FIREWALL_2-teste",
        "TRUNK_INTER_SW-teste",
        "VLAN40_CAP.TRAF2-teste",
        "VLAN20_SERVER-teste",
        "VLAN30_DASH-teste",
        "VLAN40_SIST.ALERT.-teste",
        "VLAN60_USER-teste",
      ]
    }
    vm1 = {
      nome        = "VM1"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN20_SERVER-teste"]
    }
    vm2 = {
      nome        = "VM2"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN30_DASH-teste"]
    }
    vm3 = {
      nome        = "VM3"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN40_DESCOB.HOSTS-teste"]
    }
    vm4 = {
      nome        = "VM4"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      # VM4 recebe espelhamento de AMBOS os switches (trunk bruto, sem IP
      # próprio) + uma terceira interface de gerência com IP fixo, ligada
      # ao SW1 (réplica da ens9/VLAN40_CAPT.TRAFE real de produção).
      rede_extra  = [
        "VLAN40_CAP.TRAF1-teste",
        "VLAN40_CAP.TRAF2-teste",
        "VLAN40_CAPT_TRAFE-teste",
      ]
    }
    vm6 = {
      nome        = "VM6"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      # MESMA rede da VM1 de propósito — ver nota no cabeçalho do arquivo.
      rede_extra  = ["VLAN20_SERVER-teste"]
    }
    vm7 = {
      nome        = "VM7"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN40_SIST.ALERT.-teste"]
    }
    vm9 = {
      nome        = "VM9"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN10_AUTENTICACAO-teste"]
    }
    vm11 = {
      nome        = "VM11"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      # VM11 conecta a AMBOS os trunks de firewall (liga SW1 e SW2)
      rede_extra  = [
        "FIREWALL_1-teste",
        "FIREWALL_2-teste",
      ]
    }
    vm_dev = {
      nome        = "VM_DEV"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN50_DEV-teste"]
    }
    vm_user1 = {
      nome        = "VM_USER1"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN60_USER-teste"]
    }
    vm_user2 = {
      nome        = "VM_USER2"
      flavor_name = "minor.pico.large"
      rede        = "labredes1"
      rede_extra  = ["VLAN60_USER-teste"]
    }
  }
}

# ── Criação das instâncias ───────────────────────────────────────────────────
resource "openstack_compute_instance_v2" "vms_labredes" {
  for_each = var.vms_projeto

  name            = each.value.nome
  image_id        = "f7ca5526-1dc7-4207-adff-3178b7c5e581"
  flavor_name     = each.value.flavor_name
  key_pair        = "labredes_key"
  security_groups = ["clear", "default"]

  # Interface primária — labredes1 (gerência/SSH)
  network {
    name = each.value.rede
  }

  # Interfaces extras — uma por elemento da lista rede_extra
  dynamic "network" {
    for_each = each.value.rede_extra
    content {
      name = network.value
    }
  }
}

# ── Geração do inventário Ansible (caminho de TESTE, separado do real) ──────
resource "local_file" "ansible_inventory" {
  filename = "/root/auto_deploy/ansible/hosts.ini"
  content  = <<-EOT
    # Inventário de TESTE gerado automaticamente pelo Terraform — não editar

    [todas_as_vms]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endfor ~}

    [SW1]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "SW1" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [SW2]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "SW2" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM1]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM1" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM2]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM2" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM3]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM3" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM4]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM4" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM6]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM6" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM7]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM7" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM9]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM9" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM11]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM11" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM_DEV]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM_DEV" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM_USER1]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM_USER1" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [VM_USER2]
    %{ for chave, vm in openstack_compute_instance_v2.vms_labredes ~}
    %{ if vm.name == "VM_USER2" ~}
    ${vm.name} ansible_host=${vm.network[0].fixed_ip_v4} ansible_user=ubuntu ansible_ssh_private_key_file=/root/.ssh/labredes_key%{ for i, net in vm.network } mac_net${i}=${net.mac}%{ endfor }
    %{ endif ~}
    %{ endfor ~}

    [switches:children]
    SW1
    SW2
  EOT
}
