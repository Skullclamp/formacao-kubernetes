# Laboratório Integrado — Sessão 4
## Kubernetes Admin I: de duas VMs Ubuntu a um cluster Kubernetes funcional

**Duração de referência:** 4 horas  
**Nível:** intermédio  
**Topologia:** `k8s-cp-01` + `k8s-wk-01`  
**Ambiente:** Ubuntu 26.04 LTS + Kubernetes 1.37 + `containerd` + Calico via Tigera Operator  
**Objetivo:** construir, observar, validar e administrar um cluster Kubernetes de dois nós, compreendendo o que cada comando altera e que evidências confirmam o estado esperado.

---

# Como utilizar este laboratório

Este laboratório segue a mesma regra pedagógica utilizada na Sessão 3. **Não é uma lista de comandos para copiar sem compreender.**

Em cada etapa segue a sequência:

```text
CONCEITO
   ↓
PORQUE É NECESSÁRIO
   ↓
COMANDO
   ↓
FLAGS / ARGUMENTOS
   ↓
O QUE OBSERVAR
   ↓
ERRO FREQUENTE
   ↓
BOA PRÁTICA
```

A regra da sessão é:

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR / VALIDAR
```

Os scripts existentes em [`../scripts/`](../scripts/) são auxiliares. Devem ser utilizados **depois** de os passos manuais correspondentes terem sido compreendidos.

Durante a sessão, regista evidências em [`../folha_evidencias.md`](../folha_evidencias.md).

---

# 0. Percurso completo

```text
2 VMs Ubuntu
    ↓
pré-requisitos Linux
    ↓
containerd + CRI
    ↓
kubelet / kubeadm / kubectl
    ↓
kubeadm init
    ↓
kubeconfig
    ↓
Control Plane NotReady
    ↓
Calico / Tigera Operator
    ↓
Control Plane Ready
    ↓
kubeadm join
    ↓
Worker Ready
    ↓
cluster validado
    ↓
cordon / drain / uncordon
    ↓
kubeadm upgrade plan
```

Resultado final esperado:

```text
NAME         STATUS   ROLES           ...
k8s-cp-01    Ready    control-plane   ...
k8s-wk-01    Ready    <none>          ...
```

---

# 1. Preparar os dois nós Linux

Executa esta secção em **`k8s-cp-01` e `k8s-wk-01`**, salvo indicação em contrário.

## 1.1. Confirmar identidade do nó

```bash
hostnamectl
ip -br address
```

### O que faz

- `hostnamectl` mostra e permite gerir o hostname do sistema;
- `ip -br address` apresenta, de forma compacta, as interfaces e endereços IP.

### Porque é necessário

Kubernetes identifica cada Node pelo respetivo nome. Numa formação com vários postos, nomes previsíveis reduzem erros durante `join`, `cordon`, `drain` e troubleshooting.

Confirma:

```text
Control Plane → k8s-cp-01
Worker        → k8s-wk-01
```

Se necessário:

**Control Plane**

```bash
sudo hostnamectl set-hostname k8s-cp-01
```

**Worker**

```bash
sudo hostnamectl set-hostname k8s-wk-01
```

### O que observar

Regista os IPs reais:

```text
k8s-cp-01: ______________________
k8s-wk-01: ______________________
```

---

## 1.2. Garantir resolução entre os nós

Editar `/etc/hosts` em ambos os nós:

```bash
sudo nano /etc/hosts
```

Adicionar:

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

### Elementos dos comandos

- `getent hosts` consulta a resolução de nomes configurada no sistema;
- `ping` testa conectividade IP através de ICMP;
- `-c 2` limita o teste a dois pedidos.

### O que observar

O nome deve resolver para o IP correto. Não basta o `ping` responder: confirma que **o nome aponta para a máquina pretendida**.

### Erro frequente

Copiar para `/etc/hosts` o IP de outra VM ou um endereço de uma interface NAT diferente da interface usada entre os nós.

---

## 1.3. Desativar swap no laboratório

Verificar:

```bash
swapon --show
free -h
```

Desativar:

```bash
sudo swapoff -a
```

### Conceito

Swap permite ao sistema mover páginas de memória da RAM para armazenamento secundário. O `kubelet` pode ser configurado para cenários específicos com swap, mas **neste laboratório adotamos a configuração simples com swap desativada**.

### Flags

- `swapoff` desativa áreas de swap;
- `-a` aplica a operação a todas as áreas configuradas.

Para persistir a alteração, revê `/etc/fstab`:

```bash
sudo nano /etc/fstab
```

Comenta ou remove a entrada de swap usada pela VM.

Validar novamente:

```bash
swapon --show
```

### O que observar

O comando não deve listar áreas de swap ativas.

### Boa prática

Não continues para `kubeadm init` com um preflight error sem compreender primeiro a causa.

---

## 1.4. Carregar módulos do kernel

Criar a configuração persistente:

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
```

Carregar agora:

```bash
sudo modprobe overlay
sudo modprobe br_netfilter
```

Validar:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

### Conceito

- `overlay` está relacionado com o filesystem overlay utilizado por runtimes de containers;
- `br_netfilter` permite que tráfego que atravessa bridges Linux seja visível para mecanismos de filtragem/rede quando necessário.

### Elementos importantes

- `cat <<'EOF' ... EOF` cria um *here document*;
- `tee` grava a entrada recebida num ficheiro;
- `modprobe` carrega um módulo do kernel;
- `grep -E` procura múltiplos padrões com expressões regulares estendidas.

### O que observar

As duas linhas devem aparecer em `lsmod`.

---

## 1.5. Configurar parâmetros de rede do kernel

Criar:

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
```

Aplicar:

```bash
sudo sysctl --system
```

Validar:

```bash
sysctl net.bridge.bridge-nf-call-iptables
sysctl net.ipv4.ip_forward
```

Resultado esperado:

```text
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

### Conceito

`ip_forward` permite ao host encaminhar tráfego IPv4 entre interfaces. Isto é importante num Node que participa na rede do cluster.

### Erro frequente

Criar corretamente o ficheiro em `/etc/sysctl.d/` mas esquecer `sysctl --system`, ficando a configuração ainda não aplicada na sessão atual.

---

## 1.6. Confirmar cgroup v2

```bash
stat -fc %T /sys/fs/cgroup
```

Resultado esperado no ambiente da formação:

```text
cgroup2fs
```

### Conceito

*cgroups* permitem ao Linux organizar e controlar recursos de processos. Kubernetes e o runtime usam cgroups para aplicar limites e gerir workloads.

Nesta formação queremos coerência entre:

```text
kubelet
   ↓ cgroup driver: systemd
containerd
   ↓ SystemdCgroup = true
Linux cgroup v2
```

### O que observar

Se não obtiveres `cgroup2fs`, não assumes que o laboratório está corretamente preparado. Regista a evidência e informa o formador.

---

## 1.7. Confirmar sincronização horária

```bash
timedatectl status
```

Se a VM utilizar `systemd-timesyncd`:

```bash
systemctl status systemd-timesyncd --no-pager
```

### Porque é necessário

Certificados, tokens e Events dependem de relógios coerentes. Diferenças significativas de tempo entre máquinas dificultam autenticação e diagnóstico.

### Flag

- `--no-pager` mostra a saída diretamente no terminal em vez de abrir um paginador.

---

## 1.8. Checkpoint dos pré-requisitos

Antes de avançar, completa [`../checklist.md`](../checklist.md).

Só depois da verificação manual executa:

```bash
../scripts/preflight_check.sh
```

### Porque existe o script?

O script automatiza verificações já executadas manualmente. Serve para reduzir esquecimentos, não para substituir a aprendizagem.

### O que observar

O resumo deve indicar ausência de falhas bloqueantes. Um `AVISO` deve ser interpretado; não é equivalente a um `OK`.

**Checkpoint:** regista `CP1` na folha de evidências.

---

# 2. Instalar e configurar containerd

Executar nos **dois nós**.

## 2.1. Instalar o runtime

```bash
sudo apt-get update
sudo apt-get install -y containerd
```

### O que faz

- `apt-get update` atualiza o índice de pacotes;
- `apt-get install` instala pacotes;
- `-y` aceita automaticamente as confirmações.

Validar:

```bash
containerd --version
systemctl status containerd --no-pager
```

### Conceito — onde entra containerd?

```text
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

O `kubelet` não precisa do Docker Engine para executar Pods. Comunica com um runtime compatível através do **CRI — Container Runtime Interface**.

---

## 2.2. Gerar configuração do containerd

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

### Elementos importantes

- `mkdir -p` cria o diretório e não falha se já existir;
- `containerd config default` gera uma configuração base;
- `|` encaminha a saída para `tee`;
- `> /dev/null` evita repetir no terminal todo o conteúdo gravado.

Inspecionar:

```bash
less /etc/containerd/config.toml
```

Sair do `less` com `q`.

---

## 2.3. Confirmar CRI ativo

```bash
grep -n "disabled_plugins" /etc/containerd/config.toml
```

### O que observar

Se existir uma lista `disabled_plugins`, o plugin `cri` **não deve estar desativado**.

### Porque é importante

Sem CRI funcional, o `kubelet` não consegue usar `containerd` como runtime de Pods.

---

## 2.4. Configurar SystemdCgroup

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

Validar:

```bash
grep -n "SystemdCgroup" /etc/containerd/config.toml
```

Reiniciar e ativar no boot:

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

### Elementos dos comandos

- `sed -i` altera o ficheiro diretamente;
- `restart` reinicia o serviço para aplicar a configuração;
- `enable` configura o arranque automático.

### O que observar

```bash
systemctl is-active containerd
```

Resultado esperado:

```text
active
```

---

## 2.5. Confirmar o socket do runtime

```bash
sudo ss -lx | grep containerd
```

Socket esperado:

```text
/run/containerd/containerd.sock
```

### Conceito — Unix socket

É um endpoint de comunicação local entre processos. Neste caso permite que componentes do host comuniquem com `containerd` sem expor o serviço como uma porta TCP normal.

**Checkpoint:** regista `CP2`.

---

# 3. Instalar kubelet, kubeadm e kubectl

Executar nos **dois nós**.

## 3.1. Preparar dependências APT

```bash
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo mkdir -p -m 755 /etc/apt/keyrings
```

### Porque é necessário

Vamos adicionar o repositório de pacotes Kubernetes e validar a respetiva assinatura criptográfica.

---

## 3.2. Adicionar a chave do repositório Kubernetes 1.37

```bash
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

### Flags do curl

| Flag | Função |
|---|---|
| `-f` | termina com erro em respostas HTTP de erro |
| `-s` | modo silencioso |
| `-S` | mostra erros mesmo em modo silencioso |
| `-L` | segue redirecionamentos |

### `gpg --dearmor`

Converte a chave para um formato binário apropriado para utilização pelo APT.

---

## 3.3. Adicionar o repositório

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Atualizar o índice:

```bash
sudo apt-get update
```

### Conceito

O repositório está separado por *minor version*. Nesta sessão trabalhamos com a série **1.37**.

---

## 3.4. Instalar as três ferramentas

```bash
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

### Papel de cada ferramenta

| Ferramenta | Função |
|---|---|
| `kubelet` | agente que corre em cada Node |
| `kubeadm` | bootstrap e operações de ciclo de vida do cluster |
| `kubectl` | cliente da API Kubernetes |

### `apt-mark hold`

Impede que estes pacotes sejam atualizados automaticamente por uma operação genérica do APT. Em Kubernetes, upgrades devem ser planeados e executados numa ordem controlada.

Ativar o kubelet:

```bash
sudo systemctl enable --now kubelet
```

- `--now` ativa o serviço no boot e tenta iniciá-lo imediatamente.

---

## 3.5. Comparar versões

```bash
kubeadm version
kubectl version --client
kubelet --version
```

### O que observar

As ferramentas devem pertencer à série definida para o laboratório.

### Erro frequente

Misturar inadvertidamente uma ferramenta de outra minor version por ter configurado um repositório diferente num dos nós.

---

## 3.6. Observar o kubelet antes do bootstrap

```bash
systemctl status kubelet --no-pager
journalctl -u kubelet -n 20 --no-pager
```

### Conceito

Neste momento o serviço `kubelet` existe, mas o Node ainda **não pertence a um cluster**. Ainda não recebeu a configuração produzida por `kubeadm init` ou `kubeadm join`.

### Muito importante

Não chames `CrashLoopBackOff` a este comportamento. `CrashLoopBackOff` é um estado associado a containers de Pods. Aqui estamos a observar um **serviço systemd do host**.

**Checkpoint:** regista `CP3`.

---

# 4. Inicializar o Control Plane

A partir daqui, esta secção executa-se apenas em **`k8s-cp-01`**.

## 4.1. Rever pré-condições

```bash
hostname
systemctl is-active containerd
swapon --show
sysctl net.ipv4.ip_forward
```

### Porque repetimos verificações?

Porque um bootstrap falhado devido a uma pré-condição conhecida consome mais tempo do que confirmar o estado imediatamente antes de executar `kubeadm init`.

---

## 4.2. Inicializar

```bash
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

### Conceito — bootstrap

`kubeadm init` transforma este host num Node de Control Plane preparado para receber os restantes Nodes.

De forma simplificada:

```text
preflight checks
      ↓
PKI / certificados
      ↓
configuração kubelet
      ↓
static Pods do Control Plane
      ↓
etcd
      ↓
admin.conf
      ↓
token / join information
```

### Flag

- `--pod-network-cidr=192.168.0.0/16` define o intervalo IP reservado para a rede de Pods deste laboratório.

Não especificamos `--service-cidr`, pelo que usamos o valor definido para o laboratório através do default do `kubeadm`:

```text
10.96.0.0/12
```

### O que observar

Não ignores o output final. Guarda o comando `kubeadm join` apresentado.

> O token real e o CA hash são credenciais temporárias do cluster. Não os publiques no GitHub nem os copies para documentação pública.

### Erro frequente

Reexecutar `kubeadm init` imediatamente depois de um erro parcial sem compreender que estado já ficou criado no nó. Primeiro lê a mensagem e recolhe evidências.

---

# 5. Configurar kubectl no Control Plane

## 5.1. Preparar kubeconfig

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### Conceito — kubeconfig

`kubectl` precisa de saber:

```text
que cluster contactar
        +
com que identidade
        +
que contexto utilizar
```

O ficheiro `$HOME/.kube/config` contém essa informação.

### Elementos dos comandos

- `cp -i` pede confirmação antes de substituir um ficheiro existente;
- `$(...)` executa um comando e usa o respetivo resultado;
- `id -u` devolve o UID do utilizador;
- `id -g` devolve o GID principal;
- `chown` altera o proprietário do ficheiro.

### Segurança

`admin.conf` concede privilégios administrativos elevados. **Não fazer commit** deste ficheiro nem distribuí-lo como credencial normal de utilizador.

---

## 5.2. Consultar o cluster antes do CNI

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods -n kube-system
```

### O que observar

Neste ponto, é esperado no nosso percurso observar:

```text
k8s-cp-01   NotReady   control-plane
```

### Isto é uma falha?

Não necessariamente. Ainda não instalámos uma implementação de rede CNI para os Pods.

O objetivo é perceber a transição:

```text
Control Plane criado
      ↓
CNI ainda ausente
      ↓
NotReady
      ↓
instalar CNI
      ↓
Ready
```

**Checkpoint:** regista `CP4` antes de instalar o CNI.

---

# 6. Instalar Calico com Tigera Operator

Executar em **`k8s-cp-01`**, como o utilizador que tem o `kubeconfig` administrativo configurado.

## 6.1. Conceito — CNI

Kubernetes define o modelo de rede, mas depende de uma implementação CNI para fornecer conectividade aos Pods.

Nesta sessão utilizamos **Calico** instalado através do **Tigera Operator**.

```text
CustomResourceDefinitions
        ↓
Tigera Operator
        ↓
Installation Custom Resource
        ↓
componentes Calico
        ↓
rede de Pods
```

### Porque usar um Operator?

Um Operator observa recursos declarativos e reconcilia o estado desejado dos componentes que gere. Em vez de tratarmos cada componente Calico isoladamente, declaramos a instalação pretendida e o Operator gere o respetivo ciclo de vida.

---

## 6.2. Definir explicitamente a versão Calico validada

A release a utilizar deve ser indicada pelo formador depois da validação de compatibilidade com Kubernetes 1.37.

Exemplo de preparação da variável:

```bash
export CALICO_VERSION=vX.Y.Z
```

### Porque não existe uma versão fixa no laboratório?

Porque a compatibilidade entre a versão Kubernetes da formação e a release Calico deve ser confirmada antes de cada edição. Não queremos que um script público instale silenciosamente uma versão que deixou de ser adequada.

Confirmar:

```bash
echo "$CALICO_VERSION"
```

---

## 6.3. Obter os recursos oficiais para inspeção

Depois de perceber o que será descarregado, podes utilizar o auxiliar:

```bash
CALICO_VERSION="$CALICO_VERSION" ../scripts/fetch_calico_operator.sh
```

### O que o script faz

Descarrega para uma diretoria local:

```text
v1_crd_projectcalico_org.yaml
    → CustomResourceDefinitions do Calico

tigera-operator.yaml
    → deployment e recursos do Operator

custom-resources.yaml
    → configuração declarativa da instalação
```

### O que o script NÃO faz

Não aplica automaticamente recursos ao cluster.

### Boa prática

Inspeciona os ficheiros antes de executar `kubectl create`:

```bash
less calico-${CALICO_VERSION}/custom-resources.yaml
```

---

## 6.4. Confirmar o Pod CIDR

```bash
grep -n "cidr:" calico-${CALICO_VERSION}/custom-resources.yaml
```

Para este laboratório, a configuração da rede deve ser coerente com:

```text
192.168.0.0/16
```

### Porque tem de coincidir?

Porque `kubeadm init` foi executado com esse Pod CIDR. A configuração do CNI deve implementar uma rede compatível com a decisão tomada no bootstrap.

Se o ficheiro não estiver preparado para o CIDR do laboratório, **não o apliques sem o rever**.

---

## 6.5. Criar CRDs e Operator

Assumindo que inspecionaste os ficheiros:

```bash
kubectl create -f calico-${CALICO_VERSION}/v1_crd_projectcalico_org.yaml
kubectl create -f calico-${CALICO_VERSION}/tigera-operator.yaml
```

### Conceito — CRD

Uma **CustomResourceDefinition** estende a API Kubernetes com novos tipos de recursos.

```text
API Kubernetes
   +
CRD
   ↓
novo tipo de objeto reconhecido pela API
```

Validar o Operator:

```bash
kubectl get pods -n tigera-operator
```

### O que observar

O Pod do Operator deve progredir para um estado operacional antes de esperarmos que a instalação do Calico fique reconciliada.

---

## 6.6. Aplicar os Custom Resources

Depois de confirmar a configuração:

```bash
kubectl create -f calico-${CALICO_VERSION}/custom-resources.yaml
```

### Conceito — estado desejado

Este ficheiro declara o que queremos que o Operator construa/configure.

Acompanhar:

```bash
kubectl get tigerastatus
kubectl get pods -n tigera-operator
kubectl get pods -n calico-system
```

Se quiseres observação contínua:

```bash
watch kubectl get tigerastatus
```

Sair com `Ctrl+C`.

### O que observar

O objetivo não é apenas “o comando não deu erro”. Devemos encontrar evidência de que:

```text
Operator operacional
        ↓
Calico operacional
        ↓
rede de Pods disponível
        ↓
CoreDNS Running
        ↓
Node Ready
```

Confirmar:

```bash
kubectl get pods -n kube-system
kubectl get nodes
```

**Checkpoint:** regista `CP5`.

---

# 7. Adicionar o Worker

## 7.1. Gerar um join command atual

Em `k8s-cp-01`:

```bash
kubeadm token create --print-join-command
```

### O que faz

Cria um token de bootstrap e mostra o comando completo de adesão que o Worker pode executar.

O output será semelhante a:

```text
kubeadm join <CP>:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HASH>
```

### Elementos

- `<CP>:6443` — endpoint do API Server;
- `--token` — token de bootstrap;
- `--discovery-token-ca-cert-hash` — permite ao Node validar a identidade da CA do cluster durante a descoberta.

Nunca copies os valores reais para o repositório.

---

## 7.2. Executar o join no Worker

Em **`k8s-wk-01`**, executar com `sudo` o comando real devolvido pelo Control Plane.

```bash
sudo kubeadm join <CP>:6443 --token <TOKEN> \
  --discovery-token-ca-cert-hash sha256:<HASH>
```

### Conceito

O Worker passa a:

1. descobrir o cluster;
2. autenticar o bootstrap;
3. receber configuração para o `kubelet`;
4. registar-se na API;
5. participar como Node.

### Erro frequente

Copiar um token antigo/expirado ou tentar contactar um endereço do Control Plane que não é acessível a partir do Worker.

---

## 7.3. Validar a adesão

No Control Plane:

```bash
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl cluster-info
```

### Flags

- `-o wide` acrescenta informação útil, como IP e Node associado;
- `-A` significa `--all-namespaces`.

### O que observar

```text
[ ] k8s-cp-01 Ready
[ ] k8s-wk-01 Ready
[ ] Pods Calico operacionais
[ ] CoreDNS Running
[ ] API acessível
```

**Checkpoint:** regista `CP6`.

---

# 8. Explorar kubeconfig e contextos

No Control Plane:

```bash
kubectl config view
kubectl config get-contexts
kubectl config current-context
```

### Conceito — contexto

Um contexto associa:

```text
cluster
  +
user
  +
namespace opcional
```

Isto permite que a mesma instalação de `kubectl` trabalhe com vários clusters ou identidades.

### O que observar

Identifica no teu ficheiro:

- `clusters`;
- `users`;
- `contexts`;
- `current-context`.

### Boa prática

Antes de executar uma operação administrativa importante, confirma o contexto:

```bash
kubectl config current-context
```

Executar `drain`, `delete` ou alterações noutro cluster por engano é um erro operacional evitável.

---

# 9. Manutenção controlada do Worker

Nesta etapa vamos distinguir **impedir novo scheduling** de **evacuar workloads existentes**.

## 9.1. Criar um Pod de teste no Worker

```bash
kubectl apply -f ../manifests/pod_cordon_test.yaml
```

Consultar:

```bash
kubectl get pod cordon-test -o wide
```

### Porque usamos um manifest?

O manifest contém um `nodeSelector` que fixa intencionalmente o Pod em `k8s-wk-01`. Assim o comportamento do exercício não depende de uma colocação casual do scheduler.

Inspeciona o YAML:

```bash
cat ../manifests/pod_cordon_test.yaml
```

### Conceito — Pod sem controller

Este Pod foi criado diretamente. Não existe Deployment, ReplicaSet ou outro controller responsável por garantir que ele volta a existir se for removido.

---

## 9.2. Cordon

```bash
kubectl cordon k8s-wk-01
```

Validar:

```bash
kubectl get nodes
```

### Conceito

`cordon` marca o Node como indisponível para **novo scheduling**.

```text
antes
Worker pode receber novos Pods

cordon
   ↓
depois
Worker mantém Pods atuais
mas não recebe novos Pods
```

### O que observar

O Node aparece com indicação equivalente a:

```text
SchedulingDisabled
```

### Erro frequente

Assumir que `cordon` remove os Pods existentes. Não remove.

---

## 9.3. Drain sem force

Executa primeiro:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets
```

### Conceito

`drain` prepara um Node para manutenção evacuando workloads elegíveis.

### Flag

- `--ignore-daemonsets` reconhece que Pods geridos por DaemonSets não são removidos da mesma forma pelo `drain` e evita que essa presença bloqueie o exercício.

### O que observar

O comando deve recusar avançar perante o nosso Pod direto sem controller.

### Porque esta recusa é útil?

Porque Kubernetes não tem evidência de que exista um controller capaz de recriar esse Pod noutro lugar.

```text
Pod direto
   ↓
sem owner/controller
   ↓
drain deteta risco
   ↓
recusa sem decisão explícita
```

**Não acrescentes imediatamente `--force`. Primeiro lê e explica a mensagem.**

---

## 9.4. Drain com decisão explícita no laboratório

Apenas depois de compreender a recusa:

```bash
kubectl drain k8s-wk-01 --ignore-daemonsets --force
```

### Flag `--force`

Permite ao `drain` continuar mesmo perante Pods sem um controller reconhecido.

### O que observar

```bash
kubectl get pod cordon-test -o wide
```

O Pod deixa de existir e **não é recriado automaticamente**.

### Porque não reaparece?

```text
Pod removido
   ↓
não existe controller
   ↓
não existe estado desejado a reconciliar
   ↓
ninguém cria substituto
```

Este ponto prepara a Sessão 5, onde serão trabalhados controllers e workloads como Deployments.

---

## 9.5. Uncordon

```bash
kubectl uncordon k8s-wk-01
```

Validar:

```bash
kubectl get nodes
```

### Conceito

`uncordon` devolve o Node ao conjunto de destinos elegíveis para novo scheduling.

```text
cordon   → fecha a entrada a novos workloads

drain    → evacua workloads elegíveis

uncordon → volta a abrir a entrada
```

Limpeza do objeto de teste, caso ainda exista:

```bash
kubectl delete pod cordon-test --ignore-not-found
```

- `--ignore-not-found` evita tratar como erro o facto de o Pod já ter sido removido pelo `drain`.

**Checkpoint:** regista `CP7`.

---

# 10. Manutenção planeada vs. falha

Não confundas os dois cenários.

| Manutenção planeada | Falha |
|---|---|
| administrador escolhe o momento | evento inesperado |
| pode aplicar `cordon` e `drain` | Node pode ficar `NotReady` sem preparação |
| intervenção controlada | prioridade é diagnóstico e continuidade |
| workloads podem ser preparados | workloads podem ser afetados abruptamente |

### Questão

Se um Node ficar `NotReady` inesperadamente, faz sentido executar imediatamente `uncordon`?

**Não.** Primeiro tens de perceber a causa do estado. `uncordon` altera elegibilidade de scheduling; não repara um `kubelet`, runtime, rede ou host avariado.

---

# 11. Ler um plano de upgrade

No Control Plane:

```bash
sudo kubeadm upgrade plan
```

### Objetivo da sessão

Nesta sessão **não vamos executar um upgrade multi-node completo**. Queremos aprender a interpretar o planeamento.

### Conceito

Um upgrade Kubernetes é uma operação controlada, não apenas:

```text
apt upgrade
```

A ideia operacional é:

```text
kubeadm upgrade plan
        ↓
compreender origem e destino
        ↓
planear ordem de nós
        ↓
Control Plane primeiro
        ↓
isolar/drainar quando aplicável
        ↓
atualizar componentes do Node
        ↓
validar
        ↓
Workers um de cada vez
```

### O que observar

Identifica no output:

- versão atual;
- versões de destino apresentadas;
- componentes envolvidos;
- avisos relevantes.

### Boa prática

O procedimento concreto de upgrade deve seguir a documentação correspondente às versões reais utilizadas.

Para aprofundamento:

[`../exercicios/upgrade_complementar.md`](../exercicios/upgrade_complementar.md)

---

# 12. Diagnóstico orientado por evidências

Ao surgir um problema, usa:

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
   ↓
Nova validação
```

## 12.1. Comandos Kubernetes

```bash
kubectl get nodes -o wide
kubectl describe node <node>
kubectl get pods -A -o wide
kubectl get events -A
kubectl get tigerastatus
kubectl cluster-info
```

## 12.2. Comandos no host

```bash
systemctl status kubelet --no-pager
systemctl status containerd --no-pager
journalctl -u kubelet -n 50 --no-pager
journalctl -u containerd -n 50 --no-pager
```

### Porque `describe`?

Um `get` mostra sobretudo o estado resumido. `describe` acrescenta condições, eventos e informação contextual que ajuda a formular hipóteses.

### Porque `journalctl`?

`kubelet` e `containerd` são serviços do host. Os respetivos erros podem não estar visíveis apenas com `kubectl`.

Consulta também [`../troubleshooting.md`](../troubleshooting.md).

---

# 13. Validar o cluster final

Depois de todas as etapas manuais, executa:

```bash
../scripts/verify_cluster.sh
```

### O que o script faz

Agrupa várias consultas de leitura:

- `cluster-info`;
- Nodes;
- Pods;
- estado Tigera/Calico;
- CoreDNS;
- contexto atual.

### O que o script não faz

Não decide por ti se o cluster está correto. Tens de interpretar os resultados.

Confirma manualmente:

```text
[ ] k8s-cp-01 Ready
[ ] k8s-wk-01 Ready
[ ] Worker schedulable depois do uncordon
[ ] Tigera Operator operacional
[ ] Calico operacional
[ ] CoreDNS Running
[ ] API acessível
[ ] contexto kubectl conhecido
```

Completa `CP8` da [`../folha_evidencias.md`](../folha_evidencias.md).

---

# 14. Perguntas de consolidação

Antes de terminar, responde sem consultar o manual:

1. Porque é necessário configurar o runtime antes de `kubeadm init`?
2. Qual é a função do CRI?
3. Porque usamos `SystemdCgroup = true`?
4. Que diferença existe entre `kubeadm`, `kubelet` e `kubectl`?
5. Porque observámos `NotReady` antes de instalar o CNI?
6. Que papel desempenha o Tigera Operator?
7. O Worker poderia ter executado `join` antes do CNI? O que mudaria no estado observado?
8. Que informação guarda um contexto `kubeconfig`?
9. Qual a diferença entre `cordon` e `drain`?
10. Porque foi necessário `--force` no exercício do Pod direto?
11. Porque esse Pod não foi recriado?
12. Porque `kubeadm upgrade plan` é útil mesmo sem executar o upgrade?

---

# 15. Resultado da Sessão 4

Terminamos com:

```text
Linux preparado
      ↓
containerd / CRI operacional
      ↓
Control Plane construído
      ↓
CNI operacional
      ↓
Worker integrado
      ↓
2 Nodes Ready
      ↓
kubeconfig compreendido
      ↓
manutenção básica praticada
      ↓
cluster preparado para workloads
```

Na Sessão 5, a pergunta deixa de ser **“como construímos o cluster?”** e passa a ser:

> **“Que workloads executamos neste cluster, como os expomos na rede e como preservamos os seus dados?”**
