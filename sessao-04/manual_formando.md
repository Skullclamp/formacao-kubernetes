# Manual do Formando — Sessão 4
## Kubernetes Admin I — Instalação e Administração do Cluster

**Formação:** Mini MBA em Orquestração de Containers com Kubernetes  
**Sessão:** 4 de 10  
**Módulo:** M7  
**Duração:** 4 horas  
**Nível:** Intermédio

Este manual acompanha o laboratório da Sessão 4. O objetivo não é memorizar comandos, mas compreender a sequência de construção, validação e manutenção inicial de um cluster Kubernetes com `kubeadm`.

---

# 1. Objetivo da sessão

Nas sessões anteriores trabalhámos containers, imagens, registry e operação single-host. Nesta sessão passamos a construir a plataforma que irá orquestrar os workloads das sessões seguintes.

```text
pré-requisitos Linux
        ↓
containerd / CRI
        ↓
kubelet / kubeadm / kubectl
        ↓
kubeadm init
        ↓
kubeconfig
        ↓
CNI / Calico
        ↓
kubeadm join
        ↓
validação
        ↓
manutenção
```

No final deverás conseguir:

- distinguir Control Plane e Worker;
- preparar um host Linux para Kubernetes;
- explicar a relação entre `kubelet`, CRI e `containerd`;
- inicializar o Control Plane com `kubeadm`;
- configurar o `kubeconfig`;
- instalar e validar o CNI;
- adicionar um Worker;
- validar o cluster;
- utilizar `cordon`, `drain` e `uncordon`;
- interpretar `kubeadm upgrade plan`;
- diagnosticar problemas básicos a partir de evidências.

---

# 2. Ambiente de referência

```text
Control Plane:   k8s-cp-01
Worker:          k8s-wk-01
SO:              Ubuntu 26.04 LTS
Kubernetes:      1.37
Runtime:         containerd
CNI:             Calico via Tigera Operator
Pod CIDR:        192.168.0.0/16
Service CIDR:    10.96.0.0/12
```

Cada formando trabalha com duas VMs.

> Antes da formação, deve ser confirmada a compatibilidade entre a release Calico escolhida e a versão Kubernetes utilizada. Os scripts públicos não fixam automaticamente uma versão Calico.

---

# 3. Arquitetura mínima

## Control Plane

Coordena o cluster e mantém o seu estado. No laboratório inclui, entre outros:

- `kube-apiserver`;
- `etcd`;
- `kube-scheduler`;
- `kube-controller-manager`;
- `kubelet`;
- `containerd`.

## Worker

Executa workloads e inclui:

- `kubelet`;
- `kube-proxy`;
- `containerd`.

```text
        k8s-cp-01                    k8s-wk-01
      Control Plane                    Worker
   ┌───────────────────┐         ┌───────────────────┐
   │ API Server        │         │ kubelet           │
   │ Scheduler         │         │ kube-proxy        │
   │ Controllers       │◄───────►│ containerd        │
   │ etcd              │         │                   │
   └───────────────────┘         └───────────────────┘
```

---

# 4. Preparar os dois nós

Antes de instalar Kubernetes, valida ambos os hosts. Usa também [`checklist.md`](checklist.md).

## 4.1. Hostname e rede

```bash
hostnamectl
ip -br address
```

Esperado:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
```

Regista os IPs e garante resolução entre os dois nós, por DNS ou `/etc/hosts`:

```text
<IP_CP>      k8s-cp-01
<IP_WORKER>  k8s-wk-01
```

Validar:

```bash
getent hosts k8s-cp-01
getent hosts k8s-wk-01
ping -c 2 k8s-cp-01
ping -c 2 k8s-wk-01
```

## 4.2. Swap

Neste laboratório utilizamos swap desativado:

```bash
swapon --show
sudo swapoff -a
```

Revê `/etc/fstab` para garantir persistência da configuração antes de reiniciar as VMs.

## 4.3. Módulos do kernel

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

## 4.4. Forwarding e bridge netfilter

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system
```

Validar:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
```

Ambos devem devolver `1`.

## 4.5. cgroup v2

```bash
stat -fc %T /sys/fs/cgroup
```

No ambiente definido é esperado:

```text
cgroup2fs
```

A configuração do `kubelet` e do runtime deve manter coerência no uso do driver `systemd`.

## 4.6. Tempo

```bash
timedatectl status
```

Confirma sincronização horária. Diferenças de relógio podem dificultar a análise de certificados, tokens e eventos.

---

# 5. Container runtime e CRI

Kubernetes não utiliza a CLI Docker para gerir os containers dos Pods. O `kubelet` comunica com um runtime através do **CRI — Container Runtime Interface**.

```text
Kubernetes
    ↓
kubelet
    ↓
CRI
    ↓
containerd
    ↓
runc
    ↓
Kernel Linux
```

## 5.1. Instalar containerd

Em ambos os nós:

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

Gerar configuração:

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

Configurar o driver:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

Reiniciar e ativar:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

Validar:

```bash
systemctl is-active containerd
grep -n 'SystemdCgroup' /etc/containerd/config.toml
sudo ss -lx | grep containerd
```

O socket de referência é:

```text
/run/containerd/containerd.sock
```

---

# 6. Instalar kubelet, kubeadm e kubectl

Executar em ambos os nós.

## kubeadm

Ferramenta de bootstrap e ciclo de vida administrativo do cluster.

## kubelet

Agente que corre em cada Node e comunica com o Control Plane.

## kubectl

Cliente utilizado para comunicar com a API Kubernetes.

Configura o repositório oficial `pkgs.k8s.io` correspondente à série Kubernetes 1.37 e instala as três ferramentas segundo as instruções atuais da formação.

Depois valida:

```bash
kubeadm version
kubelet --version
kubectl version --client
```

E fixa os pacotes:

```bash
sudo apt-mark hold kubelet kubeadm kubectl
```

> Instalar os três binários não significa que já exista um cluster.

---

# 7. Inicializar o Control Plane

Executar apenas em `k8s-cp-01`:

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

O `Service CIDR` fica no valor por omissão do `kubeadm`, definido para este laboratório como `10.96.0.0/12`.

No final do comando:

1. lê o output;
2. identifica o caminho do `admin.conf`;
3. guarda temporariamente o comando de `join`;
4. não publiques tokens nem hashes de descoberta.

---

# 8. Configurar kubeconfig

Ainda no Control Plane, como utilizador normal:

```bash
mkdir -p "$HOME/.kube"
sudo cp -i /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
```

Validar:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

Antes do CNI, neste laboratório é esperado observar o Control Plane como `NotReady`.

> O `admin.conf` fornece acesso administrativo elevado. Não deve ser partilhado nem versionado no Git.

---

# 9. Instalar Calico com Tigera Operator

Kubernetes necessita de uma implementação CNI para disponibilizar networking de Pods.

```text
Control Plane criado
        ↓
CNI em falta
        ↓
Node NotReady
        ↓
Calico operacional
        ↓
rede de Pods funcional
        ↓
CoreDNS Running
        ↓
Node Ready
```

## 9.1. Escolher a release

A release Calico utilizada na formação é confirmada antes da sessão. Não assumes um número de versão apenas porque aparece num exemplo antigo.

O script do repositório obriga a indicar a versão explicitamente:

```bash
CALICO_VERSION=vX.Y.Z ./scripts/fetch_calico_operator.sh
```

Este script **apenas descarrega**:

- CRDs;
- `tigera-operator.yaml`;
- `custom-resources.yaml`.

Não aplica nada automaticamente.

## 9.2. Inspecionar o Pod CIDR

```bash
grep -n 'cidr:' calico-vX.Y.Z/custom-resources.yaml
```

Para este laboratório deve ficar coerente com:

```text
192.168.0.0/16
```

## 9.3. Aplicar e validar

Depois da validação da release e da configuração:

```bash
kubectl create -f calico-vX.Y.Z/v1_crd_projectcalico_org.yaml
kubectl create -f calico-vX.Y.Z/tigera-operator.yaml
kubectl create -f calico-vX.Y.Z/custom-resources.yaml
```

Acompanhar:

```bash
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
kubectl get tigerastatus
kubectl get pods -n kube-system
kubectl get nodes
```

Objetivo: Control Plane `Ready` e CoreDNS operacional.

---

# 10. Adicionar o Worker

No Control Plane, gera um comando atual:

```bash
kubeadm token create --print-join-command
```

No Worker, executa com `sudo` o comando apresentado.

Depois valida no Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
```

Resultado esperado:

```text
k8s-cp-01   Ready   control-plane
k8s-wk-01   Ready   <none>
```

---

# 11. kubeconfig e contextos

Um `kubeconfig` contém informação sobre:

- clusters;
- users;
- contexts;
- `current-context`.

Um contexto associa principalmente:

```text
cluster + user + namespace opcional
```

Explorar:

```bash
kubectl config view
kubectl config current-context
kubectl config get-contexts
kubectl config use-context <contexto>
```

---

# 12. Manutenção: cordon, drain e uncordon

## cordon

Impede novo scheduling no Node:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
```

O Node passa a aparecer como `SchedulingDisabled`.

## Pod de observação

Aplicar o manifest preparado:

```bash
kubectl apply -f manifests/pod_cordon_test.yaml
kubectl get pod cordon-test -o wide
```

O `nodeSelector` garante que este Pod de teste é colocado em `k8s-wk-01`.

## drain

Primeiro:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

O comando deverá recusar avançar perante o Pod sem controlador.

Depois de interpretar a mensagem, apenas no contexto deste exercício:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
```

O Pod é removido e não reaparece automaticamente porque não existe Deployment, ReplicaSet ou outro controller a reconciliar o estado desejado.

## uncordon

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

---

# 13. Upgrade: princípio, não receita

Nesta sessão o percurso principal utiliza apenas:

```bash
sudo kubeadm upgrade plan
```

O objetivo é compreender:

```text
planear
   ↓
Control Plane primeiro
   ↓
seguir procedimento da versão
   ↓
isolar/drainar quando aplicável
   ↓
validar
   ↓
Workers um a um
```

Não executes `kubeadm upgrade apply` no laboratório principal. Existe um exercício complementar em [`exercicios/upgrade_complementar.md`](exercicios/upgrade_complementar.md) para ambientes descartáveis.

---

# 14. Diagnóstico orientado por evidências

Evita repetir comandos sem compreender o estado atual.

```text
Sintoma
  ↓
Evidência
  ↓
Hipótese
  ↓
Validação
  ↓
Correção
```

Comandos base:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get pods -A -o wide
kubectl describe node <node>
kubectl get events -A
kubectl get tigerastatus

systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
```

Consulta também [`troubleshooting.md`](troubleshooting.md).

---

# 15. Laboratório e evidências

Segue o percurso completo em:

[`labs/laboratorio_integrado_sessao_4.md`](labs/laboratorio_integrado_sessao_4.md)

Regista os checkpoints em:

[`folha_evidencias.md`](folha_evidencias.md)

No final, executa:

```bash
./scripts/verify_cluster.sh
```

E confirma:

```text
[ ] dois Nodes Ready
[ ] Calico operacional
[ ] CoreDNS Running
[ ] API Server acessível
[ ] Worker novamente schedulable
```

---

# 16. Autoavaliação

```text
[ ] Sei explicar Control Plane vs Worker
[ ] Sei validar pré-requisitos Linux
[ ] Sei explicar CRI e containerd
[ ] Sei executar e interpretar kubeadm init
[ ] Sei configurar kubeconfig
[ ] Sei explicar NotReady antes do CNI
[ ] Sei instalar e validar o CNI
[ ] Sei adicionar um Worker
[ ] Sei gerir contextos
[ ] Sei usar cordon, drain e uncordon
[ ] Sei explicar o efeito de --force num Pod sem controller
[ ] Sei interpretar kubeadm upgrade plan
[ ] Sei recolher evidências antes de corrigir
```

---

# 17. Continuidade para a Sessão 5

A Sessão 4 termina com:

```text
cluster instalado
      ↓
2 Nodes Ready
      ↓
CNI operacional
      ↓
acesso administrativo
      ↓
manutenção básica
```

Na Sessão 5 passamos para **Workloads, Networking, Storage e Recuperação**.
