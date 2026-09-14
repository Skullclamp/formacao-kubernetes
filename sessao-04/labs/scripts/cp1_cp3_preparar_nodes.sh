#!/usr/bin/env bash
set -Eeuo pipefail

# Sessão 4 — CP1 + CP2 + CP3
# Prepara o Linux, instala/configura containerd 2.2.6 e instala Kubernetes 1.35.8.
# Executar em CADA Node, antes de CP4/CP5.

K8S_VERSION="v1.35.8"
K8S_PKG_VERSION="1.35.8-1.1"
CONTAINERD_SERIES="2.2.6"
CP_HOSTNAME="k8s-cp-01"
CP_IP="192.168.50.46"
WK_HOSTNAME="k8s-wk-01"
WK_IP="192.168.50.65"

log()  { printf '\n[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

trap 'printf "\n[ERRO] Falha na linha %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ensure_host_entry() {
  local ip="$1"
  local host="$2"

  if grep -Eq "^[[:space:]]*${ip//./\\.}[[:space:]]+.*(^|[[:space:]])${host}([[:space:]]|$)" /etc/hosts; then
    return 0
  fi

  if grep -Eq "(^|[[:space:]])${host}([[:space:]]|$)" /etc/hosts; then
    die "Existe uma entrada /etc/hosts para ${host}, mas não corresponde a ${ip}. Corrigir antes de continuar."
  fi

  printf '%s  %s\n' "$ip" "$host" | sudo tee -a /etc/hosts >/dev/null
}

log "CP1 + CP2 + CP3 — Preparação automática do Node"

# -----------------------------------------------------------------------------
# 1. Preflight e proteção contra execução numa máquina já integrada no cluster
# -----------------------------------------------------------------------------
log "1/9 — Validar sistema operativo, hostname e estado do Node"

[[ -r /etc/os-release ]] || die "/etc/os-release não existe."
# shellcheck disable=SC1091
. /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || die "Este laboratório foi preparado para Ubuntu. Sistema atual: ${ID:-desconhecido}."
[[ "${VERSION_ID:-}" == "26.04" ]] || die "Esperava-se Ubuntu 26.04.x. Versão atual: ${VERSION_ID:-desconhecida}."

NODE_HOSTNAME="$(hostname -s)"
case "$NODE_HOSTNAME" in
  "$CP_HOSTNAME") EXPECTED_IP="$CP_IP" ;;
  "$WK_HOSTNAME") EXPECTED_IP="$WK_IP" ;;
  *) die "Hostname inesperado: ${NODE_HOSTNAME}. Esperado: ${CP_HOSTNAME} ou ${WK_HOSTNAME}." ;;
esac

ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -qx "$EXPECTED_IP" \
  || die "O IP esperado ${EXPECTED_IP} não foi encontrado em ${NODE_HOSTNAME}."

if sudo test -f /etc/kubernetes/admin.conf || sudo test -f /etc/kubernetes/kubelet.conf; then
  die "Este Node já aparenta estar inicializado/integrado num cluster. O script CP1-CP3 não deve ser executado depois de CP4/CP6."
fi

ok "Ubuntu 26.04.x, hostname e IP validados: ${NODE_HOSTNAME} / ${EXPECTED_IP}."

# -----------------------------------------------------------------------------
# 2. CP1 — observar recursos e preparar Linux
# -----------------------------------------------------------------------------
log "2/9 — Observar recursos Linux"

hostname
ip -br address
free -h
swapon --show || true
lsblk -f
df -h /
CGROUP_FS="$(stat -fc %T /sys/fs/cgroup)"
printf 'cgroup filesystem: %s\n' "$CGROUP_FS"

[[ "$CGROUP_FS" == "cgroup2fs" ]] || die "Esperava-se cgroup v2 (cgroup2fs)."

log "3/9 — Desativar swap, carregar módulos e configurar sysctl"

sudo swapoff -a

cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf >/dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf >/dev/null
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system >/dev/null

lsmod | grep -Eq '^overlay[[:space:]]' || die "Módulo overlay não está carregado."
lsmod | grep -Eq '^br_netfilter[[:space:]]' || die "Módulo br_netfilter não está carregado."
[[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] || die "net.ipv4.ip_forward não está a 1."
[[ "$(sysctl -n net.bridge.bridge-nf-call-iptables)" == "1" ]] || die "bridge-nf-call-iptables não está a 1."

if swapon --show --noheadings | grep -q .; then
  die "A swap continua ativa."
fi

ok "Swap desativada, módulos carregados e sysctl validados."

log "4/9 — Garantir resolução entre os dois Nodes"

ensure_host_entry "$CP_IP" "$CP_HOSTNAME"
ensure_host_entry "$WK_IP" "$WK_HOSTNAME"

getent hosts "$CP_HOSTNAME"
getent hosts "$WK_HOSTNAME"

ping -c 2 "$CP_HOSTNAME" >/dev/null || die "Sem conectividade ICMP para ${CP_HOSTNAME}."
ping -c 2 "$WK_HOSTNAME" >/dev/null || die "Sem conectividade ICMP para ${WK_HOSTNAME}."

ok "Resolução e conectividade entre Nodes validadas."

# -----------------------------------------------------------------------------
# 3. CP2 — instalar containerd
# -----------------------------------------------------------------------------
log "5/9 — Configurar repositório Docker e instalar containerd ${CONTAINERD_SERIES}"

sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update

CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\.6/ {print $3; exit}'
)"

[[ -n "$CONTAINERD_PKG_VERSION" ]] \
  || die "Não foi encontrada uma versão containerd.io ${CONTAINERD_SERIES} no repositório configurado."

if command_exists containerd; then
  CURRENT_CONTAINERD="$(containerd --version | awk '{print $3}')"
  if [[ "$CURRENT_CONTAINERD" != "$CONTAINERD_SERIES" ]]; then
    die "Já existe containerd ${CURRENT_CONTAINERD}. O script não fará downgrade/upgrade automático para ${CONTAINERD_SERIES}."
  fi
fi

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
sudo apt-mark hold containerd.io

# -----------------------------------------------------------------------------
# 4. CP2 — configuração containerd/CRI/cgroups
# -----------------------------------------------------------------------------
log "6/9 — Configurar containerd, CRI e SystemdCgroup"

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Garantir que CRI não fica em disabled_plugins, caso a linha exista.
if grep -Eq '^[[:space:]]*disabled_plugins[[:space:]]*=.*"cri"' /etc/containerd/config.toml; then
  sudo sed -i -E '/^[[:space:]]*disabled_plugins[[:space:]]*=/ {
    s/"cri",[[:space:]]*//g;
    s/,[[:space:]]*"cri"//g;
    s/"cri"//g;
  }' /etc/containerd/config.toml
fi

# Na configuração gerada pelo containerd 2.x, garantir SystemdCgroup=true.
grep -q 'SystemdCgroup' /etc/containerd/config.toml \
  || die "Não foi encontrada a opção SystemdCgroup no config.toml gerado."

sudo sed -i -E 's/(SystemdCgroup[[:space:]]*=[[:space:]]*)false/\1true/g' /etc/containerd/config.toml

if grep -Eq '^[[:space:]]*disabled_plugins[[:space:]]*=.*"cri"' /etc/containerd/config.toml; then
  die "CRI continua presente em disabled_plugins."
fi

grep -Eq 'SystemdCgroup[[:space:]]*=[[:space:]]*true' /etc/containerd/config.toml \
  || die "SystemdCgroup não ficou configurado como true."

sudo systemctl restart containerd
sudo systemctl enable containerd >/dev/null
sudo systemctl is-active --quiet containerd \
  || die "containerd não ficou ativo."

sudo ctr plugins ls | grep -i cri | grep -q 'ok' \
  || die "O CRI do containerd não está disponível com estado ok."

sudo containerd config dump | grep -i 'SystemdCgroup' | grep -qi 'true' \
  || die "A configuração efetiva não apresenta SystemdCgroup=true."

containerd --version
runc --version
ok "containerd, CRI e SystemdCgroup validados."

# -----------------------------------------------------------------------------
# 5. CP3 — instalar Kubernetes 1.35.8
# -----------------------------------------------------------------------------
log "7/9 — Configurar repositório Kubernetes 1.35"

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt-get update

apt-cache madison kubeadm | grep -F "$K8S_PKG_VERSION" >/dev/null \
  || die "A versão kubeadm ${K8S_PKG_VERSION} não está disponível."

if command_exists kubeadm; then
  CURRENT_KUBEADM="$(kubeadm version -o short)"
  if [[ "$CURRENT_KUBEADM" != "$K8S_VERSION" ]]; then
    die "Já existe kubeadm ${CURRENT_KUBEADM}. O script não fará downgrade/upgrade automático para ${K8S_VERSION}."
  fi
fi

log "8/9 — Instalar kubelet, kubeadm e kubectl ${K8S_VERSION}"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet >/dev/null

# Antes de init/join, o kubelet pode reiniciar por ainda não ter configuração de cluster.
# Não usamos is-active como critério final nesta fase.

# -----------------------------------------------------------------------------
# 6. Health gate CP1-CP3
# -----------------------------------------------------------------------------
log "9/9 — Validar CP1 + CP2 + CP3"

KUBEADM_VERSION="$(kubeadm version -o short)"
KUBELET_VERSION="$(kubelet --version | awk '{print $2}')"
KUBECTL_VERSION="$(kubectl version --client 2>/dev/null | awk '/Client Version:/ {print $3}')"

[[ "$KUBEADM_VERSION" == "$K8S_VERSION" ]] || die "kubeadm inesperado: ${KUBEADM_VERSION}."
[[ "$KUBELET_VERSION" == "$K8S_VERSION" ]] || die "kubelet inesperado: ${KUBELET_VERSION}."
[[ "$KUBECTL_VERSION" == "$K8S_VERSION" ]] || die "kubectl inesperado: ${KUBECTL_VERSION}."

for pkg in containerd.io kubeadm kubelet kubectl; do
  apt-mark showhold | grep -qx "$pkg" || die "${pkg} não está em hold."
done

cat <<EOF

============================================================
CP1 + CP2 + CP3 CONCLUÍDOS EM ${NODE_HOSTNAME}
============================================================
Node:                 ${NODE_HOSTNAME}
IP:                   ${EXPECTED_IP}
cgroup:               cgroup v2
swap:                 desativada
overlay/br_netfilter: carregados
ip_forward:           1
bridge-nf-call:       1
containerd:           ${CONTAINERD_SERIES}
CRI:                  disponível
SystemdCgroup:        true
kubeadm:              ${K8S_VERSION}
kubelet:              ${K8S_VERSION}
kubectl:              ${K8S_VERSION}
hold:                 containerd.io + kubeadm + kubelet + kubectl

Executar este script também no outro Node.
Quando ambos concluírem com sucesso, avançar para CP4/CP5 no k8s-cp-01.
============================================================
EOF
