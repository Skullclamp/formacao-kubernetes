#!/usr/bin/env bash
set -Eeuo pipefail

# Sessão 4 — CP1 + CP2 + CP3
# Prepara o Linux, instala/configura containerd 2.2.6 e instala Kubernetes 1.35.8.
# Executar em CADA Node, antes de CP4/CP5.
#
# IMPORTANTE:
# - este script NÃO valida nem depende de hostnames ou endereços IP específicos;
# - não altera /etc/hosts;
# - hostname, IP e resolução entre Nodes devem ser confirmados de acordo com
#   a topologia atribuída a cada formando.

K8S_VERSION="v1.35.8"
K8S_PKG_VERSION="1.35.8-1.1"
CONTAINERD_SERIES="2.2.6"

log()  { printf '\n[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

trap 'printf "\n[ERRO] Falha na linha %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

log "CP1 + CP2 + CP3 — Preparação automática do Node"

# -----------------------------------------------------------------------------
# 1. Preflight e proteção contra execução num Node já integrado no cluster
# -----------------------------------------------------------------------------
log "1/8 — Validar sistema operativo e estado do Node"

[[ -r /etc/os-release ]] || die "/etc/os-release não existe."
# shellcheck disable=SC1091
. /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] \
  || die "Este laboratório foi preparado para Ubuntu. Sistema atual: ${ID:-desconhecido}."

[[ "${VERSION_ID:-}" == "26.04" ]] \
  || die "Esperava-se Ubuntu 26.04.x. Versão atual: ${VERSION_ID:-desconhecida}."

if sudo test -f /etc/kubernetes/admin.conf || sudo test -f /etc/kubernetes/kubelet.conf; then
  die "Este Node já aparenta estar inicializado/integrado num cluster. O script CP1-CP3 não deve ser executado depois de CP4/CP6."
fi

ok "Ubuntu 26.04.x validado. Não é efetuada validação de hostname ou IP."

# -----------------------------------------------------------------------------
# 2. CP1 — observar recursos e preparar Linux
# -----------------------------------------------------------------------------
log "2/8 — Observar recursos Linux"

printf 'Hostname atual: '
hostname
printf '\nEndereços atuais:\n'
ip -br address
printf '\nMemória:\n'
free -h
printf '\nSwap atual:\n'
swapon --show || true
printf '\nDiscos/filesystems:\n'
lsblk -f
df -h /

CGROUP_FS="$(stat -fc %T /sys/fs/cgroup)"
printf '\ncgroup filesystem: %s\n' "$CGROUP_FS"

[[ "$CGROUP_FS" == "cgroup2fs" ]] \
  || die "Esperava-se cgroup v2 (cgroup2fs)."

warn "Confirmar manualmente que hostname, IP e resolução entre Nodes correspondem à topologia atribuída ao formando."

log "3/8 — Desativar swap, carregar módulos e configurar sysctl"

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

lsmod | grep -Eq '^overlay[[:space:]]' \
  || die "Módulo overlay não está carregado."

lsmod | grep -Eq '^br_netfilter[[:space:]]' \
  || die "Módulo br_netfilter não está carregado."

[[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] \
  || die "net.ipv4.ip_forward não está a 1."

[[ "$(sysctl -n net.bridge.bridge-nf-call-iptables)" == "1" ]] \
  || die "bridge-nf-call-iptables não está a 1."

if swapon --show --noheadings | grep -q .; then
  die "A swap continua ativa."
fi

ok "Swap desativada, módulos carregados e sysctl validados."

# -----------------------------------------------------------------------------
# 3. CP2 — instalar containerd
# -----------------------------------------------------------------------------
log "4/8 — Configurar repositório Docker e instalar containerd ${CONTAINERD_SERIES}"

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

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
sudo apt-mark hold containerd.io

# -----------------------------------------------------------------------------
# 4. CP2 — configuração containerd/CRI/cgroups
# -----------------------------------------------------------------------------
log "5/8 — Configurar containerd, CRI e SystemdCgroup"

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null

# Garantir que CRI não fica em disabled_plugins, caso essa linha exista.
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

sudo sed -i -E \
  's/(SystemdCgroup[[:space:]]*=[[:space:]]*)false/\1true/g' \
  /etc/containerd/config.toml

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
log "6/8 — Configurar repositório Kubernetes 1.35"

sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

sudo apt-get update

apt-cache madison kubeadm | grep -F "$K8S_PKG_VERSION" >/dev/null \
  || die "A versão kubeadm ${K8S_PKG_VERSION} não está disponível."

log "7/8 — Instalar kubelet, kubeadm e kubectl ${K8S_VERSION}"

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
log "8/8 — Validar CP1 + CP2 + CP3"

KUBEADM_VERSION="$(kubeadm version -o short)"
KUBELET_VERSION="$(kubelet --version | awk '{print $2}')"
KUBECTL_VERSION="$(kubectl version --client 2>/dev/null | awk '/Client Version:/ {print $3}')"

[[ "$KUBEADM_VERSION" == "$K8S_VERSION" ]] \
  || die "kubeadm inesperado: ${KUBEADM_VERSION}."

[[ "$KUBELET_VERSION" == "$K8S_VERSION" ]] \
  || die "kubelet inesperado: ${KUBELET_VERSION}."

[[ "$KUBECTL_VERSION" == "$K8S_VERSION" ]] \
  || die "kubectl inesperado: ${KUBECTL_VERSION}."

for pkg in containerd.io kubeadm kubelet kubectl; do
  apt-mark showhold | grep -qx "$pkg" \
    || die "${pkg} não está em hold."
done

NODE_HOSTNAME="$(hostname -s)"

cat <<EOF

============================================================
CP1 + CP2 + CP3 CONCLUÍDOS
============================================================
Node atual:            ${NODE_HOSTNAME}
cgroup:                cgroup v2
swap:                  desativada
overlay/br_netfilter:  carregados
ip_forward:            1
bridge-nf-call:        1
containerd:            ${CONTAINERD_SERIES}
CRI:                   disponível
SystemdCgroup:         true
kubeadm:               ${K8S_VERSION}
kubelet:               ${K8S_VERSION}
kubectl:               ${K8S_VERSION}
hold:                  containerd.io + kubeadm + kubelet + kubectl

Hostname/IP: não validados pelo script.
Confirmar manualmente a identidade e a conectividade segundo a topologia do formando.

Executar este script em todos os Nodes que irão participar no laboratório.
Depois de todos concluírem com sucesso, avançar para CP4/CP5 no Node escolhido como Control Plane.
============================================================
EOF
