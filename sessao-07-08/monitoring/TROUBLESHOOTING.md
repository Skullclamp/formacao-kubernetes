# Troubleshooting — instalação da stack de monitorização

Este documento complementa a preparação do laboratório integrado das Sessões 7 e 8.

O objetivo é diagnosticar de forma estruturada erros durante a preparação do chart `kube-prometheus-stack` e durante a instalação da release Helm `monitoring`.

> Regra operacional: **primeiro observar; só depois alterar**.

---

## 1. Confirmar que os materiais locais estão atualizados

No Control Plane:

```bash
cd ~/formacao-kubernetes
git pull --ff-only origin main
cd sessao-07-08
```

---

## 2. Confirmar a versão do Helm

```bash
helm version --short
```

Se o comando falhar, corrigir primeiro a instalação ou o `PATH` do Helm.

---

## 3. Diagnosticar a preparação do chart

Executar o script com tracing do Bash:

```bash
bash -x monitoring/prepare-chart.sh 91.4.1
```

O script deverá:

1. confirmar que `helm` existe;
2. adicionar/atualizar o repositório `prometheus-community`;
3. executar `helm repo update`;
4. descarregar `kube-prometheus-stack` na versão `91.4.1`;
5. criar o pacote:

```text
packages/kube-prometheus-stack-91.4.1.tgz
```

Se existir erro, guardar a mensagem completa e identificar o comando onde ocorreu.

---

## 4. Confirmar que o pacote foi criado

```bash
ls -lh packages/kube-prometheus-stack-91.4.1.tgz

helm show chart \
  packages/kube-prometheus-stack-91.4.1.tgz | head -20
```

Se o ficheiro não existir, o problema ocorreu antes da instalação da release e deve ser resolvido na fase de `helm pull`/repositório.

---

## 5. Validar os manifests antes de alterar o cluster

Renderizar localmente:

```bash
helm template monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  -f monitoring/values-lab.yaml \
  > /tmp/monitoring-rendered.yaml

echo $?
```

Resultado esperado:

```text
0
```

Se `helm template` falhar, o problema está no chart, nos `values` ou na compatibilidade de renderização e deve ser corrigido antes de executar `helm upgrade --install`.

---

## 6. Executar a instalação com diagnóstico detalhado

```bash
helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m \
  --debug
```

Se este comando falhar, **não apagar imediatamente a release, o Namespace ou as CRDs**. Recolher primeiro evidência.

---

## 7. Recolher evidência após um erro Helm

Executar imediatamente:

```bash
helm status monitoring -n monitoring || true
helm history monitoring -n monitoring || true

kubectl get pods -n monitoring -o wide

kubectl get events -n monitoring \
  --sort-by=.lastTimestamp | tail -40

kubectl get crd | grep monitoring.coreos.com
```

Quando existir um Pod em erro, aprofundar:

```bash
kubectl describe pod <POD> -n monitoring
kubectl logs <POD> -n monitoring
```

Se o Pod tiver vários containers:

```bash
kubectl get pod <POD> -n monitoring \
  -o jsonpath='{.spec.containers[*].name}{"\n"}'

kubectl logs <POD> -n monitoring -c <CONTAINER>
```

---

## 8. Confirmar se já existia uma instalação anterior

Antes de assumir que se trata de uma instalação nova:

```bash
helm list -A | grep -i monitoring || true
helm history monitoring -n monitoring || true
kubectl get namespace monitoring || true
```

Se já existir uma release ou CRDs do Prometheus Operator, tratar o caso como possível **upgrade** e não como instalação limpa.

Não remover CRDs para “resolver rapidamente” um erro sem confirmar primeiro:

- quem as instalou;
- se existem Custom Resources que dependem delas;
- se a release anterior ainda está operacional;
- qual é a causa concreta apresentada nos Events ou no output do Helm.

---

## 9. Informação mínima a recolher para diagnóstico

Quando o erro persistir, registar:

```text
1. helm version --short
2. output de bash -x monitoring/prepare-chart.sh 91.4.1
3. output de helm upgrade --install ... --debug
4. helm status monitoring -n monitoring
5. helm history monitoring -n monitoring
6. kubectl get pods -n monitoring -o wide
7. últimos Events do Namespace monitoring
8. estado das CRDs monitoring.coreos.com
```

Dar especial atenção às linhas que contenham:

```text
Error:
UPGRADE FAILED
INSTALLATION FAILED
context deadline exceeded
ImagePullBackOff
CrashLoopBackOff
FailedScheduling
FailedMount
```

---

## 10. Critério de validação

A preparação só é considerada concluída quando:

```bash
helm status monitoring -n monitoring
kubectl get pods -n monitoring
kubectl get crd prometheusrules.monitoring.coreos.com
```

confirmarem:

- release `monitoring` em estado `deployed`;
- Pods necessários da stack operacionais;
- CRD `prometheusrules.monitoring.coreos.com` disponível na API.

> Num cluster com apenas um Control Plane, evitar alterações destrutivas ou reinícios não planeados durante o laboratório.