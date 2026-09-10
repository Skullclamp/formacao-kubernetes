# C) Manual do Formando — Sessão 4
## Kubernetes Admin I — Instalação, Administração e Upgrade do Cluster

**Duração:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**SO:** Ubuntu 26.04 LTS  
**Kubernetes inicial:** 1.36.x  
**Kubernetes final:** 1.37.x  
**Baseline de referência:** 1.36.4 → 1.37.0  
**Runtime:** containerd  
**CNI:** Calico via Tigera Operator

---

# 1. Objetivo da sessão

Nesta sessão vais construir manualmente um cluster Kubernetes de dois nós e acompanhar um ciclo de vida completo:

```text
preparar
  ↓
instalar Kubernetes 1.36
  ↓
construir o cluster
  ↓
validar
  ↓
manter
  ↓
atualizar para 1.37
  ↓
validar novamente
```

O objetivo não é decorar comandos. Em cada etapa deves saber responder:

1. porque é necessária;
2. em que nó se executa;
3. que resultado esperas;
4. como confirmas esse resultado;
5. o que investigarias se o estado fosse diferente.

---

# 2. Refresh Kubernetes

## 2.1. Modelo mental

Kubernetes gere aplicações containerizadas através de uma API declarativa e de ciclos de reconciliação.

```text
estado desejado
      ↓
API Server
      ↓
controllers / scheduler
      ↓
estado real
```

## 2.2. Control Plane e Worker

**Control Plane**

- `kube-apiserver` — ponto central da API;
- `etcd` — armazenamento do estado;
- `kube-scheduler` — escolhe Nodes para Pods;
- `kube-controller-manager` — executa controllers.

**Worker**

- `kubelet` — agente do Node;
- `containerd` — runtime;
- `kube-proxy` — componente de networking de Service;
- CNI — rede de Pods.

## 2.3. Ferramentas

| Ferramenta | Papel |
|---|---|
| `kubeadm` | bootstrap e ciclo de vida do cluster |
| `kubelet` | agente de cada Node |
| `kubectl` | cliente da API Kubernetes |

Regra fundamental:

```text
kubeadm init  → apenas Control Plane
kubeadm join  → apenas Worker
```

## 2.4. Comandos e flags frequentes

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -n kube-system -o wide
kubectl describe node <NODE>
kubectl get events -A --sort-by=.lastTimestamp
```

Flags úteis:

```text
-n <namespace>   namespace específico
-A              todos os namespaces
-o wide         informação adicional
-o yaml         representação YAML
-w              acompanhar alterações
--help          ajuda do comando
```

---

# 3. Ambiente do laboratório

```text
Control Plane:       k8s-cp-01
Worker:              k8s-wk-01
Kubernetes inicial:  1.36.x
Kubernetes final:    1.37.x
Pod CIDR:            192.168.0.0/16
Service CIDR:        10.96.0.0/12
```

Cada formando utiliza duas VMs.

Antes de começar, confirma que o Pod CIDR não se sobrepõe à rede das VMs, VPN ou rede institucional.

---

# 4. Pré-requisitos Linux

Executar em **ambos os nós**.

## 4.1. Identidade e recursos

```bash
hostname
ip -br address
free -h
```

Referência mínima do laboratório: cerca de 2 vCPU e 2 GiB RAM por VM.

## 4.2. Confirmar que a VM está limpa

```bash
snap list microk8s 2>/dev/null
systemctl list-units --type=service | grep -Ei 'microk8s|k3s|minikube'
sudo ss -ltnp | grep -E ':(6443|2379|2380|10250|10257|10259)\b'
```

Se encontrares um `kube-apiserver`, `etcd`, `kubelite` ou outro Kubernetes anterior, não avances sem perceber a origem.

## 4.3. Swap

```bash
swapon --show
sudo swapoff -a
```

No laboratório, a swap fica desativada de forma persistente.

## 4.4. Módulos e sysctl

```bash
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
lsmod | grep -E 'overlay|br_netfilter'
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
stat -fc %T /sys/fs/cgroup
```

Ubuntu 26.04 utiliza cgroup v2; neste laboratório usamos o driver `systemd` de forma coerente entre kubelet e runtime.

---

# 5. containerd e CRI

Executar em ambos os nós.

```bash
sudo apt-get update
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
```

Verifica se o CRI não está desativado:

```bash
sudo grep -n 'disabled_plugins' /etc/containerd/config.toml
```

Edita:

```bash
sudo nano /etc/containerd/config.toml
```

Na configuração do runtime `runc`, garante:

```text
SystemdCgroup = true
```

Reinicia e valida a configuração efetiva:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
systemctl is-active containerd
containerd config dump | grep -i -A5 -B5 SystemdCgroup
sudo ctr plugins ls | grep -i cri
sudo ss -lx | grep containerd
```

Modelo mental:

```text
kubelet → CRI → containerd → runc → Kernel
```

---

# 6. Instalar Kubernetes 1.36.x

Executar em ambos os nós.

## 6.1. Repositório 1.36

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

## 6.2. Instalar e fixar

```bash
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
```

Validar:

```bash
kubeadm version
kubelet --version
kubectl version --client
apt-mark showhold
```

Nesta fase, as ferramentas devem pertencer à série **1.36.x**.

A baseline preparada em setembro de 2026 usa 1.36.4, mas o patch concreto deve ser confirmado antes de cada edição da formação.

---

# 7. Inicializar o Control Plane

A partir daqui, executar **apenas em `k8s-cp-01`**.

Antes do bootstrap:

```bash
hostname
free -h
systemctl is-active containerd
swapon --show
sudo ss -ltnp | grep -E ':(6443|2379|2380|10257|10259)\b'
```

Executar:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

Não uses `--ignore-preflight-errors` apenas para esconder uma causa que ainda não compreendeste.

## 7.1. Configurar kubeconfig

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

Antes do CNI, o Control Plane pode aparecer `NotReady`. Neste ponto é um estado esperado.

---

# 8. Instalar Calico via Tigera Operator

Executar no Control Plane.

A release é escolhida e validada pelo formador antes da turma. A edição de referência foi ensaiada com Calico 3.32.2.

Depois de aplicar as CRDs, o Operator e os Custom Resources, observar:

```bash
kubectl get pods -n tigera-operator -o wide
kubectl get pods -n calico-system -o wide
kubectl get tigerastatus
kubectl get nodes
```

Enquanto ainda não existir um Worker, alguns Deployments podem ficar `Pending` devido à taint:

```text
node-role.kubernetes.io/control-plane:NoSchedule
```

Não removas a taint. Confirma o motivo através de Events e avança para a integração do Worker.

## 8.1. Compatibilidade

Calico 3.32 é oficialmente testado com Kubernetes 1.34, 1.35 e 1.36. Como esta sessão termina em Kubernetes 1.37, o formador deve usar uma release oficialmente testada com 1.37 quando estiver disponível, ou pré-validar explicitamente a combinação usada.

`Funciona no laboratório` e `é oficialmente testado pelo fornecedor` são afirmações diferentes.

---

# 9. Adicionar o Worker

No Control Plane, gera um comando atual. Não guardes o resultado em ficheiros versionados; se estiver ativo o tracing da shell, desativa-o primeiro:

```bash
set +x
sudo kubeadm token create --print-join-command
```

No **`k8s-wk-01`**, executa o comando real devolvido pelo Control Plane com `sudo`.

Exemplo de estrutura:

```bash
sudo kubeadm join <ENDPOINT_REAL>:6443 \
  --token <TOKEN_REAL> \
  --discovery-token-ca-cert-hash sha256:<HASH_REAL>
```

Não executes `<TOKEN_REAL>`, `<HASH_REAL>`, `VALOR_REAL` ou `...` literalmente.

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system -o wide
kubectl get tigerastatus
```

Aguarda a convergência até os dois Nodes estarem `Ready` e CoreDNS/Calico operacionais.

---

# 10. kubeconfig e contextos

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

Um contexto associa:

```text
cluster + user + namespace opcional
```

`kubectl` pode estar instalado no Worker por uniformização do laboratório, mas o Worker não precisa de um kubeconfig administrativo para funcionar como Node.

---

# 11. Manutenção: cordon, drain e uncordon

A construção e validação do cluster 1.36.x constituem o percurso essencial. A manutenção e o upgrade seguintes formam o percurso avançado. Se uma falha impedir a continuação, o formador pode fornecer um snapshot previamente validado.

Aplica o Pod direto do laboratório:

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

## 11.1. Cordon

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

`cordon` impede novo scheduling; não remove os Pods existentes.

## 11.2. Drain sem force

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

O Pod direto sem controller deve provocar uma recusa. Lê a mensagem.

## 11.3. Drain deliberado do Pod de teste

Só neste exercício:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
```

O Pod desaparece e não é recriado porque não existe Deployment/ReplicaSet a reconciliar o estado desejado.

```bash
kubectl uncordon k8s-wk-01
```

---

# 12. Upgrade real: 1.36.x → 1.37.x

A documentação Kubernetes 1.37 descreve o upgrade direto de clusters kubeadm 1.36.x para 1.37.x. Não se saltam versões minor.

## 12.1. Estado de partida

No Control Plane:

```bash
kubectl get nodes -o wide
kubeadm version
sudo kubeadm upgrade plan
```

A baseline de referência é:

```text
1.36.4 → 1.37.0
```

O patch real é confirmado no dia da formação.

---

# 13. Upgrade do Control Plane

## 13.1. Mudar o repositório para 1.37

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-cache madison kubeadm
```

Regista a versão de pacote 1.37 disponível. Nos exemplos seguintes:

```text
<PKG_1_37> = versão APT real
<K8S_1_37> = versão semver real, por exemplo v1.37.0
```

## 13.2. Atualizar kubeadm

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='<PKG_1_37>'
sudo apt-mark hold kubeadm
kubeadm version
```

## 13.3. Planear e aplicar

```bash
sudo kubeadm upgrade plan
sudo kubeadm upgrade apply <K8S_1_37>
```

Depois:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
```

É normal observar temporariamente versões diferentes entre componentes/nós durante o processo.

## 13.4. Atualizar kubelet e kubectl

Para um upgrade minor do kubelet, o nó é drenado antes da atualização:

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='<PKG_1_37>' kubectl='<PKG_1_37>'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

```bash
kubectl uncordon k8s-cp-01
kubectl get nodes -o wide
```

---

# 14. Upgrade do Worker

No Worker, muda o repositório para 1.37 da mesma forma e atualiza primeiro o `kubeadm`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm='<PKG_1_37>'
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

A partir do Control Plane:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

Num upgrade, **não uses `--force` por rotina**. Se o drain recusar, investiga primeiro.

No Worker:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='<PKG_1_37>' kubectl='<PKG_1_37>'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

No Control Plane:

```bash
kubectl uncordon k8s-wk-01
```

---

# 15. Validação final

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get tigerastatus
kubectl cluster-info
kubectl config current-context
```

Resultado pretendido:

```text
k8s-cp-01   Ready   control-plane   v1.37.x
k8s-wk-01   Ready   <none>          v1.37.x
```

Confirma ainda:

```text
[ ] CoreDNS Running
[ ] Calico/Tigera saudável
[ ] Worker schedulable
[ ] API acessível
[ ] versões finais 1.37.x
```

---

# 16. Troubleshooting orientado por evidências

```text
Sintoma → Evidência → Hipótese → Validação → Correção
```

Comandos úteis:

```bash
kubectl get nodes -o wide
kubectl describe node <NODE>
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp
kubectl get tigerastatus
systemctl status kubelet --no-pager
journalctl -u kubelet -n 50 --no-pager
cat /etc/apt/sources.list.d/kubernetes.list
apt-cache madison kubeadm
```

Exemplos de diagnóstico:

- `init` falha por portas → procurar instalação Kubernetes residual;
- `join` indica token inválido → confirmar que não estás a executar placeholders e gerar novo comando no CP;
- APT só mostra 1.36 durante o upgrade → confirmar que o repositório foi alterado para 1.37;
- Worker continua em v1.36 → confirmar versão do kubelet e restart;
- CNI degrada após o upgrade → verificar `tigerastatus`, Pods, Events e compatibilidade da release.

---

# 17. Resumo

```text
Kubernetes 1.36
      ↓
cluster construído
      ↓
Calico + Worker
      ↓
cluster saudável
      ↓
cordon / drain / uncordon
      ↓
upgrade Control Plane
      ↓
upgrade Worker
      ↓
Kubernetes 1.37
      ↓
cluster saudável novamente
```

O resultado mais importante desta sessão não é apenas ter dois Nodes `Ready`. É compreender **como o cluster foi construído, como foi colocado em manutenção e como foi atualizado de forma controlada**.

---

# 18. Autoavaliação

```text
[ ] Sei distinguir Control Plane e Worker
[ ] Sei ler comandos kubectl e flags comuns
[ ] Sei validar os pré-requisitos Linux
[ ] Sei explicar CRI e containerd
[ ] Sei instalar Kubernetes 1.36.x
[ ] Sei executar kubeadm init apenas no CP
[ ] Sei explicar NotReady antes do CNI
[ ] Sei instalar/validar o CNI
[ ] Sei executar kubeadm join apenas no Worker
[ ] Sei usar cordon, drain e uncordon
[ ] Sei interpretar kubeadm upgrade plan
[ ] Sei atualizar o Control Plane para 1.37.x
[ ] Sei executar kubeadm upgrade node no Worker
[ ] Sei explicar version skew temporário
[ ] Sei validar Nodes, CoreDNS e CNI no final
```

---

# 19. Continuidade

A Sessão 5 começa com um cluster de dois nós já atualizado para Kubernetes 1.37.x. O foco passa então para workloads, networking e storage.
