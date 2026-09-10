# Exercício Complementar — Upgrade do Cluster

## Sessão 4 · Kubernetes Admin I

Este exercício tem duas partes. A Parte 1 é de planeamento e pode ser realizada sem alterar o cluster. A Parte 2 é opcional e só deve ser executada num ambiente de laboratório descartável, com snapshot de recuperação disponível.

---

# Parte 1 — Planeamento

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
seguir o procedimento da versão
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

# Parte 2 — Aplicação real opcional

Só avances se:

- o cluster for descartável;
- existir um snapshot de recuperação testado;
- tiveres concluído a Parte 1;
- compreenderes o output do `kubeadm upgrade plan`.

> Não fixamos neste exercício uma versão de destino. Usa sempre uma versão suportada e indicada pelo plano/documentação correspondente ao cluster real.

## 1. Distinguir versão Kubernetes e versão do pacote

```text
K8S_TARGET   → versão usada pelo kubeadm, por exemplo v1.37.x
PKG_VERSION  → versão do pacote APT correspondente
```

Antes de avançar:

```bash
sudo apt-cache madison kubeadm
```

Regista os valores reais e não executes placeholders literalmente.

## 2. Control Plane

Em `k8s-cp-01`, atualizar primeiro `kubeadm` de acordo com a documentação da versão escolhida:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm="${PKG_VERSION}"
sudo apt-mark hold kubeadm

sudo kubeadm upgrade apply "${K8S_TARGET}"
```

Antes de atualizar o kubelet, prepara o nó de acordo com o procedimento oficial e com os workloads presentes. Num laboratório em que se decide drenar:

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
kubectl get nodes
```

## 3. Worker

Em `k8s-wk-01`:

```bash
sudo apt-mark unhold kubeadm
sudo apt-get update
sudo apt-get install -y kubeadm="${PKG_VERSION}"
sudo apt-mark hold kubeadm
sudo kubeadm upgrade node
```

A partir do Control Plane, isolar e drenar o Worker:

```bash
kubectl cordon k8s-wk-01
kubectl get nodes
kubectl drain k8s-wk-01 --ignore-daemonsets
```

> Não uses `--force` por omissão num upgrade. Se o `drain` recusar por causa de um Pod sem controller, investiga e toma uma decisão consciente.

No Worker:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet="${PKG_VERSION}" kubectl="${PKG_VERSION}"
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

No Control Plane:

```bash
kubectl uncordon k8s-wk-01
kubectl get nodes
```

## 4. Validação final

```bash
kubectl get nodes -o wide
kubectl version
kubectl get pods -A
kubectl cluster-info
```

Confirmar:

```text
[ ] ambos os nós Ready
[ ] versões coerentes com o destino escolhido
[ ] nenhum Pod de sistema em Error/CrashLoopBackOff
```

## 5. Reflexão

1. Porque atualizamos primeiro o Control Plane?
2. Porque se valida cada nó antes de continuar?
3. Porque um `drain` falhado deve ser investigado antes de usar `--force`?
4. Como mudaria o procedimento num cluster com vários Workers?
5. Que mecanismos adicionais seriam exigidos num Control Plane em alta disponibilidade?

O objetivo principal deste exercício é compreender a disciplina operacional de um upgrade. Rollback avançado, HA e recuperação de `etcd` são aprofundados noutras sessões.
