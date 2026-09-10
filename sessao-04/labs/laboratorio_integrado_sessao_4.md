# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: instalar 1.35.x, operar e atualizar para 1.36.x

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`

## Baseline de referência

```text
Ubuntu:              26.04 LTS
Kubernetes inicial:  1.35.x
Kubernetes final:    1.36.x
containerd:          2.2.x
Calico:              3.32.2
Tigera Operator:     1.42.6
Pod CIDR:            192.168.0.0/16
Service CIDR:        10.96.0.0/12
```

Os patches concretos disponíveis devem ser confirmados antes de cada edição. O laboratório fixa uma versão real descoberta no repositório APT; não instala simplesmente a minor mais recente.

> Este percurso 1.35.x → 1.36.x está em validação prática. Só deve ser considerado baseline ensaiada depois de todo o laboratório, incluindo o upgrade e a recuperação, passar sem anomalias não explicadas.

## Método

```text
COMPREENDER → EXECUTAR MANUALMENTE → OBSERVAR → REGISTAR EVIDÊNCIA → EXPLICAR
```

Usa `../folha_evidencias.md` durante o percurso.

## Regras de localização dos comandos

```text
k8s-cp-01
  ├─ kubeadm init
  ├─ kubeadm token create
  ├─ kubectl ...
  └─ kubeadm upgrade apply

k8s-wk-01
  ├─ sudo kubeadm join ...
  ├─ kubeadm upgrade node
  └─ kubelet / containerd
```

- Valores entre `< >` são placeholders de documentação e nunca são executados literalmente.
- `kubeadm join` exige privilégios de root: usar `sudo`.
- O Worker não recebe um kubeconfig administrativo para o utilizador interativo; a administração com `kubectl` é feita a partir do Control Plane.
- Não usar `--ignore-preflight-errors`, `--force` ou alterações de segurança como resposta automática a um erro.

---

# CP1 — Confirmar identidade e limpar o ponto de partida

Executar nos **dois nós**.

```bash
hostname
ip -br address
free -h
swapon --show
```

Esperado:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
```

## 1.1. Confirmar que não existe Kubernetes residual

```bash
snap list microk8s 2>/dev/null || true
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube' || true
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b' || true

dpkg-query -W -f='${Package} ${Version}\n' kubeadm kubelet kubectl 2>/dev/null || true

grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true
```

Se a VM já tiver Kubernetes 1.36/1.37 ou um cluster anterior, **não fazer downgrade ad hoc**. No laboratório, restaurar a VM/snapshot limpo e recomeçar.

## 1.2. Swap, módulos e sysctl

```bash
sudo swapoff -a

cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

Validar:

```bash
swapon --show
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
timedatectl status
```

## 1.3. Resolução entre nós

Regista os IPs reais e configura `/etc/hosts` em ambos:

```text
<IP_CP>      k8s-cp-01
<IP_WORKER>  k8s-wk-01
```

Depois substitui os placeholders pelos IPs reais e valida:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

---

# CP2 — Instalar containerd 2.2.x

Executar nos **dois nós**.

A série 2.2.x é usada como referência comum ao percurso Kubernetes 1.35/1.36. Nesta edição, o laboratório instala `containerd.io` a partir do repositório Docker; a combinação exata de package/runc deve ser registada durante a validação.

## 2.1. Repositório Docker para `containerd.io`

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"${UBUNTU_CODENAME:-$VERSION_CODENAME}\") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
apt-cache madison containerd.io
```

Selecionar o patch 2.2.x mais recente disponível:

```bash
CONTAINERD_PKG_VERSION="$(
  apt-cache madison containerd.io |
  awk '$3 ~ /^2\.2\./ {print $3; exit}'
)"

printf 'containerd.io selecionado: %s\n' "$CONTAINERD_PKG_VERSION"
test -n "$CONTAINERD_PKG_VERSION"

sudo apt-get install -y containerd.io="$CONTAINERD_PKG_VERSION"
```

## 2.2. Configuração CRI e cgroups

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo nano /etc/containerd/config.toml
```

Confirmar:

```text
1. cri NÃO está em disabled_plugins
2. SystemdCgroup = true nas opções do runtime runc
```

Depois:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd

containerd --version
runc --version
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

Registar também a proveniência do runtime:

```bash
dpkg -S "$(command -v runc)" 2>/dev/null || true
apt-cache policy containerd.io containerd runc apparmor
```

Modelo mental:

```text
kubelet → CRI → containerd → runc → kernel
```

---

# CP3 — Instalar exatamente Kubernetes 1.35.x

Executar nos **dois nós**.

## 3.1. Configurar o repositório da minor 1.35

```bash
grep -R "pkgs.k8s.io/core:/stable:" \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true

sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
apt-cache madison kubeadm
```

## 3.2. Fixar explicitamente um package 1.35.x

```bash
K8S_PKG_VERSION="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.35\./ {print $3; exit}'
)"

printf 'Kubernetes package: %s\n' "$K8S_PKG_VERSION"
test -n "$K8S_PKG_VERSION"

sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION" \
  kubeadm="$K8S_PKG_VERSION" \
  kubectl="$K8S_PKG_VERSION"

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Validar:

```bash
kubeadm version -o short
kubelet --version
kubectl version --client
apt-mark showhold
```

**Não avançar se aparecer 1.36 ou 1.37.**

---

# CP4 — Inicializar o Control Plane em 1.35.x

Executar **apenas em `k8s-cp-01`**.

```bash
hostname

test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: kubeadm init só pode ser executado em k8s-cp-01"
  exit 1
}
```

Derivar a versão a partir do package instalado:

```bash
K8S_PKG_VERSION="$(dpkg-query -W -f='${Version}' kubeadm)"
K8S_SEMVER="v${K8S_PKG_VERSION%%-*}"
printf 'Bootstrap Kubernetes: %s\n' "$K8S_SEMVER"
```

Inicializar:

```bash
sudo kubeadm init \
  --kubernetes-version="$K8S_SEMVER" \
  --pod-network-cidr=192.168.0.0/16
```

Configurar `kubectl` para o utilizador administrativo do Control Plane:

```bash
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, `NotReady` pode ser esperado.

---

# CP5 — Instalar Calico 3.32.2 via Tigera Operator

Executar no **Control Plane**.

## 5.1. Instalar CRDs e Tigera Operator

```bash
export CALICO_VERSION=v3.32.2

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/v1_crd_projectcalico_org.yaml

kubectl create -f \
  https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml
```

Validar o Operator e a imagem:

```bash
kubectl get pods -n tigera-operator -o wide
kubectl -n tigera-operator get deploy tigera-operator \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Para esta release, a imagem esperada é `quay.io/tigera/operator:v1.42.6`.

## 5.2. Aplicar apenas o CNI/core networking necessário à Sessão 4

O `custom-resources.yaml` completo da release também ativa APIServer, Goldmane e Whisker. Esses componentes são úteis noutros contextos, mas **não são objetivos desta sessão** e aumentam o número de workloads num cluster pedagógico de apenas dois nós.

Por isso, nesta sessão usamos um manifesto controlado contendo apenas o recurso `Installation`:

```bash
cat ../manifests/calico_installation_sessao4.yaml
kubectl create -f ../manifests/calico_installation_sessao4.yaml
```

Confirmar o CIDR antes de criar:

```bash
grep -n 'cidr:' ../manifests/calico_installation_sessao4.yaml
```

Esperado:

```text
192.168.0.0/16
```

Validar convergência:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get nodes -o wide
```

Não avançar enquanto o core Calico estiver `Progressing=True` ou `Degraded=True`.

---

# CP6 — Gerar o join no Control Plane e integrar o Worker

## 6.1. Gerar o comando — APENAS `k8s-cp-01`

```bash
hostname

test "$(hostname -s)" = "k8s-cp-01" || {
  echo "ERRO: o token de join é criado no Control Plane, não no Worker"
  exit 1
}
```

Gerar o comando real:

```bash
set +x
sudo kubeadm token create --print-join-command \
  --kubeconfig=/etc/kubernetes/admin.conf
```

O resultado tem esta **estrutura**, mas deves copiar os valores reais produzidos pelo teu cluster:

```text
kubeadm join IP_REAL_DO_CP:6443 --token TOKEN_REAL --discovery-token-ca-cert-hash sha256:HASH_REAL
```

Se aparecer:

```text
failed to load admin kubeconfig: open /root/.kube/config: no such file or directory
```

confirma:

```bash
hostname
sudo ls -l /etc/kubernetes/admin.conf
```

Se estás em `k8s-wk-01`, estás no nó errado. **Não copies `admin.conf` para o Worker.**

## 6.2. Executar o join — APENAS `k8s-wk-01`

No Worker:

```bash
hostname

test "$(hostname -s)" = "k8s-wk-01" || {
  echo "ERRO: kubeadm join só pode ser executado em k8s-wk-01"
  exit 1
}
```

Executar com privilégios de root o **comando real** gerado no Control Plane:

```text
sudo kubeadm join IP_REAL_DO_CP:6443 --token TOKEN_REAL --discovery-token-ca-cert-hash sha256:HASH_REAL
```

Não executar literalmente:

```text
<IP_CONTROL_PLANE>
<TOKEN>
<HASH>
...
```

Em Bash, `<` e `>` são operadores de redirecionamento; escrever `<IP_CONTROL_PLANE>` literalmente pode originar:

```text
-bash: IP_CONTROL_PLANE: No such file or directory
```

Executar `kubeadm join` sem `sudo` origina:

```text
[ERROR IsPrivilegedUser]: user is not running as root
```

A correção é `sudo kubeadm join ...`, não ignorar o preflight.

## 6.3. Validar o join no sítio certo

No Worker, **não usar `kubectl get nodes` como validação do cluster**. Sem kubeconfig administrativo, o `kubectl` pode tentar `localhost:8080` e devolver `connection refused`.

No Worker, validar localmente:

```bash
sudo systemctl is-active kubelet
sudo systemctl status kubelet --no-pager
sudo ls -l /etc/kubernetes/kubelet.conf
```

O ficheiro `/etc/kubernetes/kubelet.conf` deve existir após um `join` bem-sucedido.

No **Control Plane**, validar o estado global:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get pods -n tigera-operator -o wide
kubectl get tigerastatus
```

Aguardar até os dois Nodes estarem `Ready` e o core Calico/CoreDNS estarem operacionais.

---

# CP7 — Manutenção pedagógica: cordon, drain seletivo e uncordon

Executar os comandos `kubectl` no **Control Plane**.

> Num cluster de apenas dois nós, um `drain` integral do único Worker pode evacuar componentes de sistema que não fazem parte do objetivo deste exercício. Além disso, o Tigera Operator possui tolerations amplas e pode voltar a ser agendado num nó cordoned, criando churn de Pods durante um drain. Nesta demonstração, o `drain` é por isso limitado ao Pod de teste.

## 7.1. Criar e observar o Pod de teste

```bash
kubectl apply -f ../manifests/pod_cordon_test.yaml
kubectl wait --for=condition=Ready pod/cordon-test --timeout=120s
kubectl get pod cordon-test -o wide
```

Confirmar que está no Worker e observar antes da manutenção o que corre nesse nó:

```bash
kubectl get pods -A \
  --field-selector spec.nodeName=k8s-wk-01 \
  -o wide
```

## 7.2. Cordon

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

## 7.3. Primeiro drain seletivo — sem `--force`

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test
```

Esperado: o comando deve recusar a remoção do `cordon-test`, porque é um Pod direto sem controller.

## 7.4. Drain seletivo controlado

Só para demonstrar conscientemente o efeito de `--force` sobre **este Pod de teste**:

```bash
kubectl drain k8s-wk-01 \
  --ignore-daemonsets \
  --pod-selector=app=cordon-test \
  --force
```

Validar que apenas o Pod de teste foi afetado:

```bash
kubectl get pod cordon-test
kubectl get pods -A \
  --field-selector spec.nodeName=k8s-wk-01 \
  -o wide
```

Reabrir o nó:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes -o wide
```

> O `drain` integral continua a ser necessário no upgrade real do kubelet. A demonstração acima é seletiva apenas para evitar perturbar desnecessariamente componentes de sistema durante a aprendizagem do comando.

---

# CP8 — Gate de saúde e ponto de recuperação antes do upgrade

**Não criar o snapshot nem iniciar o upgrade enquanto este gate não estiver limpo.**

## 8.1. Validar o cluster a partir do Control Plane

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
```

Critérios mínimos:

```text
Nodes:              Ready
Calico core:         Available=True / Degraded=False
CoreDNS:             Running/Ready
Evicted em ciclo:    não
ContainerStatusUnknown em ciclo: não
```

Se aparecerem dezenas/centenas de Pods `tigera-operator` `Evicted`/`ContainerStatusUnknown`, **PARAR**. Não continuar para o upgrade.

## 8.2. Verificar o runtime no Worker

```bash
sudo systemctl is-active kubelet
sudo systemctl is-active containerd
containerd --version
runc --version

sudo journalctl -u kubelet -n 100 --no-pager \
  | grep -Ei 'unable to signal init|permission denied|KillContainer|KillPodSandbox' || true
```

Se aparecer algo semelhante a:

```text
runc did not terminate successfully: ... unable to signal init: permission denied
```

não assumir a causa. Recolher evidência do kernel:

```bash
sudo aa-status
sudo journalctl -k --since "-30 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|audit.*DENIED|runc|containerd' || true
```

Se o kernel mostrar `apparmor="DENIED"` associado a runc/containerd, a hipótese AppArmor fica confirmada. **Não desativar AppArmor globalmente como tentativa.** Registar a evidência e consultar `../troubleshooting.md`.

## 8.3. Confirmar que ainda estamos em 1.35.x

No Control Plane:

```bash
kubeadm version -o short
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

No Worker:

```bash
kubeadm version -o short
kubelet --version
```

Não executar exemplos antigos com placeholders como `<PKG_1_37>` ou `<PKG_...>`.

## 8.4. Criar o ponto de retorno

Só depois do gate estar saudável, criar snapshots coordenados das duas VMs:

```text
k8s-cp-01 → pre-upgrade-1.35
k8s-wk-01 → pre-upgrade-1.35
```

Se o upgrade falhar gravemente no laboratório, este é o ponto de retorno. Não se ensina um downgrade APT improvisado.

---

# CP9 — Upgrade do Control Plane: 1.35.x → 1.36.x

Executar primeiro em **`k8s-cp-01`**.

## 9.1. Mudar o repositório para 1.36 e calcular a versão real

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

K8S_PKG_VERSION_136="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"

printf 'Pacote destino: %s\n' "$K8S_PKG_VERSION_136"
test -n "$K8S_PKG_VERSION_136"

K8S_TARGET="v${K8S_PKG_VERSION_136%%-*}"
printf 'Kubernetes destino: %s\n' "$K8S_TARGET"
```

## 9.2. Atualizar `kubeadm` e o Control Plane

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm

kubeadm version -o short
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply "$K8S_TARGET"
```

Validar antes de tocar no kubelet:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
```

É normal o Node do Control Plane ainda apresentar kubelet 1.35.x nesta fase; o Control Plane já foi atualizado, mas o kubelet ainda não.

## 9.3. Drain do Control Plane e upgrade do kubelet/kubectl

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

Depois:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION_136" \
  kubectl="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Reabrir e validar:

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

Neste momento, o Worker ainda deve estar em 1.35.x. Este version skew temporário é esperado durante o upgrade sequencial.

---

# CP10 — Upgrade do Worker para 1.36.x

## 10.1. Preparar `kubeadm` no Worker

No **Worker**:

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update

K8S_PKG_VERSION_136="$(
  apt-cache madison kubeadm |
  awk '$3 ~ /^1\.36\./ {print $3; exit}'
)"

printf 'Pacote destino Worker: %s\n' "$K8S_PKG_VERSION_136"
test -n "$K8S_PKG_VERSION_136"

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubeadm

kubeadm version -o short
sudo kubeadm upgrade node
```

## 10.2. Preparar o drain integral sem provocar churn do Tigera Operator

Os comandos `kubectl` seguintes são executados no **Control Plane**.

Primeiro observar onde está o Tigera Operator:

```bash
kubectl -n tigera-operator get pods -o wide
kubectl get pods -A \
  --field-selector spec.nodeName=k8s-wk-01 \
  -o wide
```

O Tigera Operator 3.32.2 tolera genericamente `NoSchedule` e `NoExecute`. Num cluster de dois nós, se estiver no Worker pode voltar a ser colocado no próprio Worker mesmo depois de este ficar unschedulable. **Não iniciar o drain se estiver a ocorrer esse ciclo.**

Se o Pod do Operator estiver no Worker, nesta topologia pedagógica pode ser temporariamente fixado ao Control Plane antes do drain:

```bash
kubectl -n tigera-operator patch deployment tigera-operator \
  --type=merge \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"k8s-cp-01"}}}}}'

kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=120s
kubectl -n tigera-operator get pods -o wide
```

Só avançar quando o cluster continuar saudável.

## 10.3. Drain integral do Worker — a partir do Control Plane

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Este é o drain real associado à atualização do kubelet. Se falhar, **ler a mensagem e parar**; não acrescentar `--force` automaticamente.

## 10.4. Atualizar kubelet/kubectl — no Worker

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y \
  kubelet="$K8S_PKG_VERSION_136" \
  kubectl="$K8S_PKG_VERSION_136"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet

kubelet --version
sudo systemctl status kubelet --no-pager
```

## 10.5. Uncordon — a partir do Control Plane

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes -o wide
```

Se o `nodeSelector` temporário do Tigera Operator foi acrescentado em 10.2, removê-lo agora:

```bash
kubectl -n tigera-operator patch deployment tigera-operator \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector/kubernetes.io~1hostname"}]'

kubectl -n tigera-operator rollout status deployment/tigera-operator --timeout=120s
```

---

# CP11 — Validação final

Executar no **Control Plane**:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Esperado:

```text
k8s-cp-01   Ready   control-plane   v1.36.x
k8s-wk-01   Ready   <none>          v1.36.x
```

Confirmar versões/runtime de forma inequívoca:

```bash
kubectl get nodes \
  -o custom-columns=NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion
```

Confirmar componentes:

```bash
kubectl get pods -n kube-system -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n tigera-operator -o wide
```

A validação final não é apenas “os comandos terminaram”: não deve existir churn persistente de Pods, Nodes `NotReady`, componentes Calico `Degraded` nem erros do runtime ao terminar containers.

---

# Se algo correr mal

```text
PARAR
  ↓
recolher evidência
  ↓
não avançar para o próximo nó
  ↓
identificar a causa
  ↓
decidir correção ou restauro
```

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | tail -n 100
kubectl get tigerastatus
```

No nó afetado:

```bash
sudo systemctl status kubelet --no-pager
sudo systemctl status containerd --no-pager
sudo journalctl -u kubelet -n 100 --no-pager
sudo journalctl -k --since "-30 min" --no-pager \
  | grep -Ei 'apparmor="DENIED"|audit.*DENIED|runc|containerd' || true
sudo ls -la /etc/kubernetes/tmp/ 2>/dev/null || true
```

Num laboratório descartável, se o upgrade deixar o estado inconsistente e a causa não puder ser corrigida com segurança, restaurar os snapshots coordenados `pre-upgrade-1.35`.

Consulta também [`../troubleshooting.md`](../troubleshooting.md) e [`../compatibilidade.md`](../compatibilidade.md).
