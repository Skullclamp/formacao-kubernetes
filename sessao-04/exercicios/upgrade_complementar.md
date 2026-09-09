# Exercício Complementar — Upgrade do Cluster

## Sessão 4 · Kubernetes Admin I

Este exercício tem **duas partes**, com níveis de risco diferentes. A Parte 1 é para todos. A Parte 2 só se aplica ao ambiente descartável do laboratório, com snapshot de recuperação disponível.

---

# Parte 1 — Planeamento (obrigatória, sem risco)

Podes fazer esta parte em qualquer altura, sozinho, sem supervisão do formador — não altera nada no cluster.

## A. Estado atual

```bash
kubeadm version
kubelet --version
kubectl version --client
kubectl get nodes
```

Regista as versões.

## B. Plano

```bash
sudo kubeadm upgrade plan
```

Responde:

1. Qual a versão instalada?
2. Que destinos aparecem?
3. Há indicação de version skew?
4. Que componentes são referidos?

## C. Sequência conceptual

```text
kubeadm upgrade plan
        ↓
planear a intervenção
        ↓
Control Plane primeiro
        ↓
seguir procedimento da versão
        ↓
isolar/drainar quando aplicável
        ↓
atualizar componentes do nó
        ↓
validar
        ↓
Workers, um de cada vez
```

## D. Questões

1. Porque não tratar Kubernetes como um simples `apt upgrade`?
2. Porque validar após cada nó?
3. Que impacto pode o `drain` ter nos workloads?
4. Porque a documentação da versão concreta tem prioridade?

---

# Parte 2 — Aplicação real (opcional, requer ambiente descartável)

**Só avances para aqui se:**

- [ ] o teu cluster corre num ambiente que podes destruir sem consequências;
- [ ] tens um snapshot de recuperação disponível e testado;
- [ ] já completaste a Parte 1 e compreendeste o output do teu `kubeadm upgrade plan`.

Se alguma destas condições não se verificar, **fica pela Parte 1**.

> **Nota sobre versões:** não fixamos aqui uma versão de destino. Usa sempre a que o teu `kubeadm upgrade plan` te indicou como disponível.

### Duas versões diferentes, não confundir

```text
K8S_TARGET   → versão passada ao kubeadm, formato semver com "v": ex. v1.37.4
PKG_VERSION  → versão do pacote APT, com sufixo de build: ex. 1.37.4-1.1
```

Antes de avançar, define as duas a partir do que confirmaste na Parte 1:

```bash
sudo apt-cache madison kubeadm

K8S_TARGET=v1.37.x
PKG_VERSION=1.37.x-1.1
```

Substitui os valores pelos números reais apresentados no teu ambiente.

## 1. Atualizar o Control Plane

Em `k8s-cp-01`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm="${PKG_VERSION}"
sudo apt-mark hold kubeadm

sudo kubeadm upgrade apply "${K8S_TARGET}"
```

Drenar o nó antes de atualizar o `kubelet`:

```bash
kubectl drain k8s-cp-01 --ignore-daemonsets
```

Atualizar `kubelet` e `kubectl`:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubelet="${PKG_VERSION}" kubectl="${PKG_VERSION}"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Devolver o nó ao serviço:

```bash
kubectl uncordon k8s-cp-01
```

Validar antes de continuar:

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

## 2. Atualizar o Worker — com isolamento

Em `k8s-wk-01`, atualizar primeiro o `kubeadm` e executar a fase de upgrade do nó:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm="${PKG_VERSION}"
sudo apt-mark hold kubeadm

sudo kubeadm upgrade node
```

> `kubeadm upgrade node` não recebe a versão como argumento; usa a versão do binário `kubeadm` já instalado no passo anterior.

Antes de atualizar o `kubelet`, isolar e drenar o Worker a partir do Control Plane:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
kubectl drain k8s-wk-01 --ignore-daemonsets
```

> **Não uses `--force` aqui por omissão.** Se o `drain` recusar por encontrar um Pod sem controlador, para e investiga a causa antes de decidir como proceder.

Em `k8s-wk-01`, atualizar então `kubelet` e `kubectl`:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet="${PKG_VERSION}" kubectl="${PKG_VERSION}"
sudo apt-mark hold kubelet kubectl

sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

Devolver o Worker ao serviço, a partir do Control Plane:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

## 3. Validação final

```bash
kubectl get nodes -o wide
kubectl version
kubectl get pods -A
kubectl cluster-info
```

Confirma:

- [ ] ambos os nós na versão de destino;
- [ ] ambos os nós `Ready`;
- [ ] nenhum Pod de sistema em `CrashLoopBackOff` ou `Error`.

## 4. Reflexão final

1. Porque atualizamos o Control Plane antes do Worker?
2. O que teria acontecido se tivesses corrido `kubeadm upgrade apply` sem ler primeiro `kubeadm upgrade plan`?
3. Porque isolamos e drenamos um Node antes de atualizar o `kubelet`?
4. Num cluster com vários Workers, porque os devemos atualizar um de cada vez?

---

## Fora do âmbito

- rollback de um upgrade falhado;
- upgrade de Control Plane em alta disponibilidade;
- backup/restore de `etcd` antes do upgrade.

Estes temas são aprofundados na Sessão 7.
