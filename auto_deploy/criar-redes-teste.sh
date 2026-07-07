#!/bin/bash
# =============================================================================
# criar-redes-teste.sh
#
# Cria REDES EXCLUSIVAS DE TESTE (não compartilhadas com produção) no
# projeto/tenant de TESTE, com nomes sufixados "-teste" e CIDRs no bloco
# reservado 10.99.x.0/24 — completamente isolado do bloco de produção
# 10.0.x.0/24 usado pelas VLANs reais do laboratório.
#
# CONTEXTO IMPORTANTE: descobrimos que as VLANs "de nome igual" ao trabalho
# (VLAN10_AUTENTICACAO, VLAN20_SERVER, etc.) já existem como redes
# COMPARTILHADAS no domínio do IFES, usadas por todos os grupos/projetos.
# Usar essas redes diretamente faria a VM de teste compartilhar o mesmo
# domínio L2 e o mesmo range de IP da produção — risco real de colisão.
# Por isso este script cria uma topologia paralela, com nomes e IPs próprios,
# que não colide com nada de ninguém.
#
# PRÉ-REQUISITOS:
#   1. Ter uma entrada "labredes-teste" configurada em ~/.config/openstack/clouds.yaml
#      com os *_endpoint_override corretos apontando para o project_id do
#      projeto de teste (não copiar os overrides do bloco de produção sem ajustar).
#   2. Estar logado com um usuário que tenha permissão de criar redes nesse projeto
#
# USO:
#   chmod +x criar-redes-teste.sh
#   ./criar-redes-teste.sh
#
# Cada rede é criada SEM DHCP e SEM GATEWAY, replicando o padrão do ambiente
# real (DHCP e Gateway desabilitados, IPs fixos definidos via Netplan/Ansible).
# =============================================================================

set -e  # aborta o script no primeiro erro

export OS_CLOUD=labredes-teste

echo ">>> Usando cloud: $OS_CLOUD"
echo ">>> Projeto atual:"
openstack project show $(openstack token issue -f value -c project_id) -f value -c name
echo ""
read -p "Confirma que este é o PROJETO DE TESTE (não o de produção)? Digite 'sim' para continuar: " confirmacao
if [ "$confirmacao" != "sim" ]; then
  echo "Abortado pelo usuário."
  exit 1
fi

# NOTA: "labredes1" NÃO está nesta lista de propósito. Ela é uma rede
# compartilhada usada só para gerência/SSH (fora do escopo de isolamento
# deste teste) e já está disponível automaticamente no projeto novo.
#
# IMPORTANTE: VLAN20_MOT.ANAL. (VM6) e VLAN20_SERVER (VM1) são, na topologia
# REAL de produção, a MESMA sub-rede física/L2 (10.0.20.0/24) — o switch
# (SW2) trata ambas com a mesma tag 802.1Q "20", conectando VM1 e VM6 na
# MESMA porta/VLAN. Criar duas redes Neutron separadas (mesmo com CIDR
# igual) NÃO as uniria na mesma L2 — seriam broadcast domains diferentes,
# como dois prédios com apartamentos de mesmo número mas em endereços
# diferentes. Por isso aqui existe UMA ÚNICA rede para a tag 20
# (VLAN20_SERVER-teste), e tanto a VM1 quanto a VM6 devem se conectar a
# ela no instances.tf-teste.

# IMPORTANTE: VLAN60_USER1 (SW1) e VLAN60_USER2 (SW2) também compartilham a
# MESMA tag 802.1Q "60" em produção — exatamente como VLAN20_SERVER/MOT.ANAL.
# Este é, inclusive, o par usado no teste de homologação original do
# Aluno 5 para validar o TRUNK_INTER_SW (ping cruzado entre VM_USER1 e
# VM_USER2 atravessando o backbone). Por isso, uma ÚNICA rede de teste
# serve as duas VMs.

# Formato de cada linha: nome_da_rede;CIDR
REDES=(
  "VLAN10_AUTENTICACAO-teste;10.99.10.0/24"
  "VLAN10_DEPLOY-teste;10.99.11.0/24"
  "VLAN20_SERVER-teste;10.99.20.0/24"
  "VLAN30_DASH-teste;10.99.30.0/24"
  "VLAN40_CAP.TRAF1-teste;10.99.41.0/24"
  "VLAN40_CAP.TRAF2-teste;10.99.42.0/24"
  "VLAN40_DESCOB.HOSTS-teste;10.99.40.0/24"
  "VLAN40_SIST.ALERT.-teste;10.99.43.0/24"
  "VLAN40_CAPT_TRAFE-teste;10.99.44.0/24"
  "VLAN50_DEV-teste;10.99.50.0/24"
  "VLAN60_USER-teste;10.99.60.0/24"
  "FIREWALL_1-teste;10.99.251.0/24"
  "FIREWALL_2-teste;10.99.252.0/24"
  "TRUNK_INTER_SW-teste;10.99.70.0/24"
)

for entrada in "${REDES[@]}"; do
  nome="${entrada%%;*}"
  cidr="${entrada##*;}"

  echo ""
  echo "=== Criando rede: $nome ($cidr) ==="

  # Cria a rede (se já existir, o comando falha e o script para por causa do 'set -e')
  openstack network create "$nome"

  # Cria a sub-rede associada, sem DHCP e sem gateway
  openstack subnet create \
    --network "$nome" \
    --subnet-range "$cidr" \
    --no-dhcp \
    --gateway none \
    "${nome}-subnet"

  echo "✔ $nome criada com sucesso"
done

echo ""
echo "============================================================"
echo "Todas as 15 VLANs de TESTE foram criadas, isoladas de produção."
echo "(labredes1 já existia como rede compartilhada — não foi recriada)"
echo "Verifique com: openstack network list"
echo ""
echo "PRÓXIMO PASSO: ajuste o instances.tf de teste para usar os nomes"
echo "com sufixo '-teste' em rede_extra (ex: VLAN20_SERVER-teste em vez"
echo "de VLAN20_SERVER), e ajuste os IPs fixos nos netplans dos playbooks"
echo "para o bloco 10.99.x.x, já que 10.0.x.x não existe nesta topologia."
echo "============================================================"
