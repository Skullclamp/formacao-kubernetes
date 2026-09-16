# Incidente 4 — Release candidata não fica operacional

## Como utilizar este incidente

Este incidente é realizado em **modo acompanhado**. O formador explica primeiro os conceitos de Helm, conduz o health gate, lança a release candidata com a turma e orienta a leitura do histórico, estado do Deployment, Pods, EndpointSlices e Events.

A causa não é revelada antes da recolha de evidência, mas este não é um exercício autónomo. O formador vai colocando perguntas e decide quando a turma tem evidência suficiente para avançar para a causa raiz e para o rollback.

---

## Situação

A aplicação já é gerida por Helm. Uma nova release candidata é aplicada, mas o rollout não termina com sucesso. Uma réplica anterior continua disponível enquanto a nova réplica evidencia a falha.

## Objetivo pedagógico

Compreender e observar a sequência:

```text
Chart
  ↓
Values
  ↓
Release
  ↓
Revision
  ↓
Upgrade
  ↓
Falha
  ↓
Diagnóstico
  ↓
Rollback
  ↓
Nova revision
```

E perceber por que razão um rollback é preferível a editar manualmente o Deployment neste cenário.

---

# 1. Conceitos antes de executar comandos

## Helm

Helm é um gestor de pacotes para Kubernetes. Permite definir aplicações através de templates e valores configuráveis, instalá-las como releases e manter histórico das alterações.

## Chart

Um `Chart` é o pacote Helm. Contém templates Kubernetes, metadados e valores por defeito.

Neste laboratório:

```text
helm/app-lab/
```

é o Chart da aplicação Symfony.

## Values

Os ficheiros `values.yaml` permitem alterar parâmetros sem editar diretamente os templates.

Exemplo conceptual:

```yaml
image:
  repository: ...
  tag: ...
```

## Release

Uma `Release` é uma instalação concreta de um Chart num cluster/Namespace.

Neste laboratório:

```text
symfony-lab
```

é a release da aplicação.

## Revision

Cada instalação, upgrade ou rollback cria uma entrada histórica numerada.

```text
revision 1 → estado inicial
revision 2 → upgrade
revision 3 → rollback ou novo upgrade
```

## Rollback

`helm rollback` recupera a configuração de uma revisão anterior, mas cria **uma nova revisão**. O histórico permanece disponível.

---

# 2. Health gate — confirmar uma baseline boa

Executar em conjunto:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Como interpretar os comandos

```text
helm list
→ mostra as releases existentes no Namespace

helm history
→ mostra todas as revisions da release e o respetivo estado

kubectl get deployment
→ confirma READY, AVAILABLE e estado do rollout

kubectl get pods -o wide
→ mostra estado, IP e Node das réplicas

EndpointSlice -o yaml
→ permite confirmar conditions.ready dos endpoints
```

### Checkpoint acompanhado

Não avançar enquanto a turma não confirmar:

```text
release ativa
Deployment 2/2
2 Pods Ready
2 endpoints ready=true
```

O formador pede também que seja identificada a revisão atualmente conhecida como boa.

---

# 3. Aplicar a release candidata

Executar:

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

## Comando e flags

```text
helm upgrade symfony-lab
→ atualiza a release existente

./helm/app-lab
→ Chart usado para renderizar os manifests

-f helm/values/values-broken.yaml
→ fornece os valores da release candidata

-n s78-lab
→ Namespace da release

--wait
→ espera pelas condições de prontidão suportadas pelo Helm

--timeout 90s
→ termina a espera ao fim de 90 segundos se o estado pretendido não for alcançado
```

Neste exercício é esperado que a candidata não fique operacional dentro do tempo definido.

---

# 4. Observar o efeito do upgrade

Depois da falha do comando, executar em conjunto:

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

## O que observar

O formador conduz a leitura por esta ordem:

```text
1. Qual é agora o estado da release?
2. Foi criada uma nova revision?
3. Quantas réplicas estão Ready?
4. Existe uma réplica anterior ainda utilizável?
5. Qual é o estado do novo Pod?
6. O EndpointSlice exclui a réplica não pronta?
7. Que Events explicam a falha?
```

---

# 5. Aprofundar o diagnóstico do novo Pod

Identificar o novo Pod afetado e definir:

```bash
POD=<NOVO_POD>
```

Executar:

```bash
kubectl describe pod "$POD" -n s78-lab
kubectl get pod "$POD" -n s78-lab \
  -o jsonpath='{.spec.containers[0].image}{"\n"}'
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

## Como interpretar

```text
kubectl describe pod
→ mostra estado do container, razão da espera e Events associados

jsonpath
→ extrai apenas o campo pretendido do objeto devolvido pela API

.spec.containers[0].image
→ imagem configurada no primeiro container do Pod

.spec.template.spec.containers[0].image
→ imagem definida no Pod template do Deployment
```

O formador orienta a turma a relacionar:

```text
estado do container
        ↓
Event persistente
        ↓
configuração realmente aplicada
```

Só depois se fecha a causa raiz.

---

# 6. Porque não corrigir com `kubectl edit`

Neste exercício, o Deployment pertence à release Helm.

Uma alteração manual no objeto vivo criaria divergência entre:

```text
estado no cluster
        ≠
estado descrito pela release Helm
```

Esta divergência é uma forma de **configuration drift**.

Por isso, a recuperação deve ser feita através do mecanismo que gere a release.

---

# 7. Identificar a revisão boa e executar rollback

Primeiro confirmar novamente o histórico:

```bash
helm history symfony-lab -n s78-lab
```

O formador pergunta:

```text
Qual era a última revision comprovadamente saudável?
Que evidência temos de que estava saudável?
```

Depois executar:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab \
  --wait \
  --timeout 3m
```

## Como interpretar

```text
helm rollback
→ cria uma nova revision cujo conteúdo deriva da revisão escolhida

<REVISAO_BOA>
→ número obtido do histórico, não um valor assumido previamente

--wait
→ espera pela convergência dos recursos

--timeout 3m
→ limita a espera a três minutos
```

---

# 8. Validar a recuperação

Executar:

```bash
helm history symfony-lab -n s78-lab
helm status symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo \
  -n s78-lab \
  --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## O que a turma deve provar

```text
release atual       → deployed
nova revision       → criada pelo rollback
Deployment          → 2/2
Pods                → 2 × Ready
EndpointSlice       → 2 endpoints ready=true
```

---

# 9. Registo na folha de evidências

| Campo | Registo |
|---|---|
| Revisão boa inicial | |
| Revisão candidata | |
| Sintoma observado | |
| Evidência principal | |
| Estado da réplica anterior | |
| Estado do novo Pod | |
| Hipótese formulada | |
| Teste utilizado | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Nova revisão criada | |
| Evidência final | |

## Síntese a consolidar

```text
Helm mantém histórico da release
upgrade pode falhar sem apagar a revisão anterior
rollback não apaga o incidente
rollback cria uma nova revision
editar manualmente recursos geridos por Helm cria drift
recuperação só termina depois de validada
```
