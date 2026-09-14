#!/usr/bin/env bash
set -Eeuo pipefail

# Sessão 4 — CP4 + CP5
# Inicializa o Control Plane Kubernetes 1.35.8 e instala Calico 3.32.2.
# Executar apenas em k8s-cp-01, depois de concluídos CP0 a CP3.

K8S_VERSION="v1.35.8"
CP_HOSTNAME="k8s-cp-01"
CP_IP="192.168.50.46"
POD_CIDR="10.244.0.0/16"
CRI_SOCKET="unix:///run/containerd/containerd.sock"
CALICO_VERSION="v3.32.2"

REPO_DIR="${HOME}/formacao-kubernetes"
MANIFEST_DIR="${REPO_DIR}/sessao-04/manifests"
CALICO_INSTALLATION="${MANIFEST_DIR}/calico_installation_sessao4.yaml"
CALICO_INSTALLATION_URL="https://raw.githubusercontent.com/Skullclamp/formacao-kubernetes/main/sessao-04/manifests/calico_installation_sessao4.yaml"

log()  { printf '\n[INFO] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[ERRO] %s\n' "$*" >&2; exit 1; }

trap 'printf "\n[ERRO] Falha na linha %s: %s\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

wait_for_calico_pods() {
  local i
  for i in $(seq 1 60); do
    if kubectl get pods -n calico-system --no-headers 2>/dev/null | grep -q .; then
      return 0
    fi
    sleep 5
  done
  return 1
}

log "CP4 + CP5 — Inicialização do Control Plane e instalação do Calico"

# -----------------------------------------------------------------------------
# 1. Preflight
# -----------------------------------------------------------------------------
log "1/8 — Validar o Node e os pré-requisitos"

[[ "$(hostname -s)" == "$CP_HOSTNAME" ]] \
  || die "Este script só pode ser executado em ${CP_HOSTNAME}. Host atual: $(hostname -s)"

ip -4 -o addr show | awk '{print $4}' | cut -d/ -f1 | grep -qx "$CP_IP" \
  || die "O IP ${CP_IP} não foi encontrado neste Node."

for cmd in kubeadm kubelet kubectl containerd curl; do
  command_exists "$cmd" || die "Comando em falta: $cmd. Concluir primeiro CP0 a CP3."
done

sudo systemctl is-active --quiet containerd \
  || die "containerd não está ativo. Corrigir CP2 antes de continuar."

[[ "$(kubeadm version -o short)" == "$K8S_VERSION" ]] \
  || die "kubeadm não está em ${K8S_VERSION}. Versão atual: $(kubeadm version -o short)"

kubelet --version | grep -q "${K8S_VERSION}" \
  || die "kubelet não está em ${K8S_VERSION}."

sudo ctr plugins ls | grep -i cri | grep -q '\bok\b' \
  || die "O plugin CRI do containerd não está disponível com estado ok."

containerd config dump | grep -i 'SystemdCgroup' | grep -qi 'true' \
  || die "SystemdCgroup não está configurado como true."

ok "Node, versões, containerd, CRI e cgroups validados."

# -----------------------------------------------------------------------------
# 2. kubeadm init
# -----------------------------------------------------------------------------
log "2/8 — Inicializar o Control Plane"

if sudo test -f /etc/kubernetes/admin.conf; then
  warn "/etc/kubernetes/admin.conf já existe; kubeadm init não será repetido."
else
  sudo kubeadm init \
    --kubernetes-version="$K8S_VERSION" \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --cri-socket="$CRI_SOCKET"
fi

# -----------------------------------------------------------------------------
# 3. kubeconfig
# -----------------------------------------------------------------------------
log "3/8 — Configurar o kubeconfig administrativo"

sudo test -f /etc/kubernetes/admin.conf \
  || die "admin.conf não existe depois do kubeadm init."

mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"

kubectl cluster-info >/dev/null
ok "API Server acessível por kubectl."

SERVER_VERSION="$(kubectl version 2>/dev/null | awk '/Server Version:/ {print $3}')"
[[ "$SERVER_VERSION" == "$K8S_VERSION" ]] \
  || die "A versão do API Server é ${SERVER_VERSION:-desconhecida}; esperava-se ${K8S_VERSION}."

log "Estado intermédio esperado antes do CNI:"
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide

# -----------------------------------------------------------------------------
# 4. CRDs + Tigera Operator
# -----------------------------------------------------------------------------
log "4/8 — Instalar CRDs do Calico e Tigera Operator ${CALICO_VERSION}"

kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml"

kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"

kubectl rollout status deployment/tigera-operator \
  -n tigera-operator --timeout=180s

ok "Tigera Operator disponível."

# -----------------------------------------------------------------------------
# 5. Manifesto Installation da formação
# -----------------------------------------------------------------------------
log "5/8 — Obter e validar o manifesto Installation"

mkdir -p "$MANIFEST_DIR"

if [[ ! -f "$CALICO_INSTALLATION" ]]; then
  warn "Manifesto local não encontrado; a descarregar da branch main."
  curl -fsSL "$CALICO_INSTALLATION_URL" -o "$CALICO_INSTALLATION"
fi

[[ -s "$CALICO_INSTALLATION" ]] \
  || die "Manifesto Calico inexistente ou vazio: $CALICO_INSTALLATION"

grep -Eq 'cidr:[[:space:]]*10\.244\.0\.0/16' "$CALICO_INSTALLATION" \
  || die "O manifesto não contém o Pod CIDR esperado: ${POD_CIDR}"

ok "Manifesto encontrado e Pod CIDR validado: ${POD_CIDR}."

kubectl apply -f "$CALICO_INSTALLATION"

# -----------------------------------------------------------------------------
# 6. Esperar pela convergência do Calico
# -----------------------------------------------------------------------------
log "6/8 — Aguardar os Pods do Calico"

wait_for_calico_pods \
  || die "Não surgiram Pods em calico-system dentro do tempo esperado."

kubectl wait --for=condition=Ready pod --all \
  -n calico-system --timeout=300s

ok "Pods de calico-system Ready."

# -----------------------------------------------------------------------------
# 7. Esperar por Node e CoreDNS
# -----------------------------------------------------------------------------
log "7/8 — Aguardar Control Plane Ready e CoreDNS"

kubectl wait --for=condition=Ready "node/${CP_HOSTNAME}" --timeout=300s
kubectl rollout status deployment/coredns -n kube-system --timeout=300s

ok "Control Plane Ready e CoreDNS disponível."

# -----------------------------------------------------------------------------
# 8. Health gate CP4 + CP5
# -----------------------------------------------------------------------------
log "8/8 — Validar o resultado final"

kubectl get nodes -o wide
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide
kubectl get tigerastatus

CALICO_AVAILABLE="$(kubectl get tigerastatus calico -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)"
IPPOOLS_AVAILABLE="$(kubectl get tigerastatus ippools -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)"
NODE_READY="$(kubectl get node "$CP_HOSTNAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')"

[[ "$NODE_READY" == "True" ]] \
  || die "O Control Plane ainda não está Ready."

[[ "$CALICO_AVAILABLE" == "True" ]] \
  || die "tigerastatus/calico ainda não está Available=True."

[[ "$IPPOOLS_AVAILABLE" == "True" ]] \
  || die "tigerastatus/ippools ainda não está Available=True."

cat <<'EOF'

============================================================
CP4 + CP5 CONCLUÍDOS
============================================================
Control Plane:        Ready
Kubernetes:           v1.35.8
Pod CIDR:             10.244.0.0/16
Calico:               Available=True
IP pools:             Available=True
CoreDNS:              disponível

Nota: nesta instalação mínima, tigerastatus/tiers pode aparecer
Degraded por ausência deliberada do Tigera API Server. O critério
pedagógico deste bloco é o core Calico/ippools saudável e o Node Ready.

Próximo passo: CP6 — gerar o kubeadm join e integrar o Worker.
============================================================
EOF
