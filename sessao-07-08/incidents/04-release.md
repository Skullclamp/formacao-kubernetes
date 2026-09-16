# Incidente 4 — Release candidata não fica operacional

## Situação entregue ao formando

A aplicação já é gerida por Helm. Uma nova release candidata é aplicada, mas o rollout não termina com sucesso. A estratégia de atualização permite que uma réplica anterior continue disponível enquanto a nova réplica evidencia a falha.

A causa **não é fornecida**. Deve ser descoberta a partir do estado da release, Pods, Events e configuração efetivamente aplicada.

---

## Objetivo

Aplicar novamente:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

E compreender os conceitos operacionais de Helm:

```text
Chart
  ↓
Release
  ↓
Revision
  ↓
Upgrade
  ↓
Rollback
```

No final, o formando deve conseguir explicar por que razão um rollback é preferível a uma edição manual do Deployment neste cenário.

---

## Conceitos a compreender antes de iniciar

### Helm

Helm é um gestor de pacotes para Kubernetes. Permite agrupar templates, valores configuráveis e metadados num `Chart`, instalar esses recursos como uma `Release` e manter histórico das alterações.

### Chart

Um `Chart` é o pacote que contém os templates Kubernetes e os valores por defeito necessários para produzir manifests.

Neste laboratório:

```text
helm/app-lab/
```

é o chart da aplicação Symfony.

### Values

Os ficheiros de values permitem alterar parâmetros do chart sem editar diretamente os templates.

Exemplo conceptual:

```yaml
image:
  repository: ...
  tag: ...
```

### Release

Uma Release é uma instalação concreta de um Chart num cluster/Namespace.

Neste laboratório:

```text
symfony-lab
```

é o nome da release.

### Revision

Cada alteração à release gera uma revisão no histórico Helm.

Exemplo conceptual:

```text
revision 1 → instalação inicial
revision 2 → upgrade
revision 3 → rollback ou novo upgrade
```

### Rollback

`helm rollback` recupera o estado de uma revisão anterior, mas o faz criando **uma nova revisão**. O histórico não é apagado.

Isto é importante para auditabilidade operacional.

---

# 1. Health gate — confirmar uma release conhecida como boa

Antes de introduzir a candidata:

```bash
helm list -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Como interpretar os comandos

```text
helm list
→ lista releases no Namespace

helm history symfony-lab
→ mostra todas as revisões conhecidas da release

kubectl get deployment
→ confirma estado agregado da aplicação

kubectl get endpointslices
→ confirma se o Service tem backends prontos
```

### O que observar

Não avançar sem:

```text
release STATUS=deployed
Deployment 2/2 Ready
2 Pods Ready
2 endpoints ready=true
```

Registar a revisão atual. Essa informação poderá ser necessária mais tarde.

---

# 2. Aplicar a release candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o comando não conclua com sucesso dentro do tempo definido.

### Como interpretar o comando e as flags

```text
helm upgrade symfony-lab
→ altera a release existente chamada symfony-lab

./helm/app-lab
→ chart usado para renderizar a nova configuração

-n s78-lab
→ Namespace da release

-f helm/values/values-broken.yaml
→ fornece valores específicos para esta candidata

--wait
→ mantém o comando à espera de condições de prontidão suportadas pelo Helm

--timeout 90s
→ limita a espera a 90 segundos
```

### O que significa um timeout

Um timeout do Helm é um **sintoma**, não uma causa raiz.

```text
UPGRADE FAILED: context deadline exceeded
```

apenas prova que a release não atingiu as condições esperadas dentro do prazo.

É necessário investigar o cluster para descobrir porquê.

> Não abrir imediatamente `values-broken.yaml` à procura da resposta. Primeiro diagnosticar através do estado observado.

---

# 3. Consultar o estado da release

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
```

### Conceitos

`helm status` mostra o estado atual da release.

`helm history` permite comparar a revisão anteriormente conhecida como boa com a nova candidata.

Registar:

```text
revisão anterior
revisão candidata
STATUS da candidata
DESCRIPTION
```

Uma revisão marcada como `failed` não implica que todos os recursos criados por essa revisão tenham desaparecido. O estado real do cluster deve ser observado com `kubectl`.

---

# 4. Observar Deployment, Pods e endpoints

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### O que observar

No Deployment:

```text
READY
UP-TO-DATE
AVAILABLE
```

Nos Pods:

```text
Pod antigo vs Pod novo
READY
STATUS
NODE
```

No EndpointSlice:

```yaml
conditions:
  ready:
  serving:
```

### Questão de análise

A aplicação ficou totalmente indisponível ou a estratégia do Deployment preservou pelo menos uma réplica anterior utilizável?

A resposta deve ser sustentada pelos endpoints, não apenas pelo número de Pods.

---

# 5. Recolher Events

```bash
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

### O que procurar

Events relacionados com:

```text
novo ReplicaSet
criação do novo Pod
scheduling
arranque do container
imagem
probes
back-off
```

Os Events ajudam a reduzir o espaço de hipóteses.

---

# 6. Inspecionar o novo Pod afetado

Identificar primeiro o Pod criado pela nova revisão:

```bash
kubectl get pods -n s78-lab -o wide
```

Depois:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
```

Se a hipótese justificar, inspecionar também campos concretos:

```bash
kubectl get pod <NOVO_POD> -n s78-lab \
  -o jsonpath='{.spec.containers[0].image}{"\n"}'

kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

### Como interpretar

```text
jsonpath
→ extrai diretamente um campo da representação devolvida pela API
```

Comparar Pod e Deployment ajuda a provar se o problema está realmente no estado desejado atual da release.

---

# 7. Formular a hipótese e provar a causa raiz

Registar:

```text
Sintoma:

Evidência:

Hipótese:

Teste:

Causa raiz:
```

A causa raiz deve explicar simultaneamente:

```text
porque a nova réplica falha
porque o Helm atinge timeout
porque a réplica anterior pode continuar disponível
```

---

# 8. Escolher a revisão conhecida como boa

Antes do rollback:

```bash
helm history symfony-lab -n s78-lab
```

Não assumir que a revisão boa é sempre `1`.

O critério é identificar a revisão que estava operacional **antes da candidata defeituosa**.

Registar explicitamente:

```text
REVISAO_BOA=<número>
```

---

# 9. Efetuar rollback

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab \
  --wait \
  --timeout 3m
```

### Como interpretar

```text
helm rollback symfony-lab <REVISAO_BOA>
→ pede ao Helm que restaure o conteúdo de uma revisão anterior

--wait
→ aguarda condições de prontidão

--timeout 3m
→ limita o tempo de espera
```

### Conceito essencial

O rollback não “volta atrás no número da revisão”. Em vez disso:

```text
revision antiga boa
        ↓
conteúdo reutilizado
        ↓
nova revision criada
        ↓
histórico preservado
```

---

# 10. Validar a recuperação

```bash
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo \
  -n s78-lab \
  --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### O que observar

A recuperação deve demonstrar:

```text
nova revisão Helm → deployed
Deployment        → 2/2 Ready
Pods              → 2 × Ready
Endpoints         → 2 × ready=true
```

---

## Porque não usar `kubectl edit` neste exercício?

Editar manualmente o Deployment poderia alterar o estado do cluster, mas criaria divergência entre:

```text
estado gerido pelo Helm
        ≠
estado alterado manualmente
```

Isto é **configuration drift**.

Num fluxo gerido por Helm, a correção deve ser realizada através do mecanismo que é fonte de verdade da release:

```text
nova release corrigida
        ou
helm rollback
```

Neste exercício pratica-se deliberadamente o rollback.

---

## Registo do incidente

| Campo | Registo |
|---|---|
| Revisão boa inicial | |
| Revisão candidata | |
| Estado Helm da candidata | |
| Estado da réplica anterior | |
| Estado da nova réplica | |
| Endpoints ainda disponíveis | |
| Sintoma | |
| Evidência principal | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Revisão escolhida para rollback | |
| Nova revisão criada pelo rollback | |
| Estado após rollback | |
| Endpoints após rollback | |

---

## CHECKPOINT — Incidente 4 concluído

Não avançar enquanto não for possível demonstrar:

```text
release candidata falhou
causa raiz identificada por evidência
revisão boa identificada
rollback executado
nova revisão Helm deployed
Deployment 2/2
2 endpoints ready=true
```

E explicar:

```text
Helm mantém histórico de revisions
rollback restaura conteúdo anterior
rollback cria uma nova revision
edição manual criaria drift
```
