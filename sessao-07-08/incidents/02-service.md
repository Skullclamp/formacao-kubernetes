# Incidente 2 — Pods saudáveis, Service sem resposta

## Situação entregue ao formando

Os Pods da aplicação estão `Running` e `Ready`. O objeto `Service` existe, mas os pedidos enviados através do Service não chegam à aplicação.

A causa **não é fornecida**. O objetivo é diagnosticar a cadeia entre Service, selectors, labels e EndpointSlices.

---

## Objetivo

Aplicar o método:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

E compreender que:

```text
Service existente ≠ Service com backends utilizáveis
```

---

## Conceitos a compreender antes de diagnosticar

### Service

Um `Service` fornece um ponto de acesso estável a um conjunto dinâmico de Pods.

Os Pods podem ser destruídos e recriados com novos IPs; o Service evita que clientes tenham de conhecer esses IPs diretamente.

### Selector

Na configuração mais comum, o Service encontra os seus backends através de um `selector` baseado em labels.

Exemplo conceptual:

```yaml
selector:
  app: minha-app
```

O Service procura Pods cujas labels correspondam a esse selector.

### Labels

Labels são pares chave/valor associados aos objetos Kubernetes. São usadas para organizar, selecionar e relacionar recursos.

Exemplo:

```yaml
labels:
  app: minha-app
  role: web
```

### EndpointSlice

O controlador de EndpointSlices observa Services e Pods e mantém a lista de endpoints elegíveis.

A relação a demonstrar neste incidente é:

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
      ↓
backends disponíveis ao Service
```

Se o selector não corresponder a nenhum Pod, o objeto Service pode continuar perfeitamente existente, mas sem backends para encaminhar tráfego.

---

## Regras do incidente

- Confirmar primeiro o estado dos Pods.
- Não assumir imediatamente que existe um problema de CNI ou DNS.
- Comparar explicitamente labels dos Pods com selectors do Service.
- Validar o EndpointSlice associado especificamente ao Service `symfony-demo`.
- Não corrigir através de `kubectl edit`.
- Repor a baseline declarativa conhecida como boa depois de confirmada a causa raiz.

---

# 1. Confirmar que o workload está saudável

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide --show-labels
```

### Como interpretar os comandos e flags

```text
kubectl get deployment symfony-demo
→ mostra o estado agregado do workload

kubectl get pods
→ mostra cada réplica individual

-o wide
→ acrescenta IP e Node, úteis para relacionar Pods com endpoints

--show-labels
→ acrescenta ao output as labels atribuídas a cada Pod
```

### O que observar

Confirmar antes de investigar a rede:

```text
Deployment → 2/2 Ready
Pods       → Running / Ready
```

Se os Pods não estiverem saudáveis, o incidente já não é exclusivamente de Service e deve ser diagnosticado primeiro ao nível do workload.

---

# 2. Inspecionar o Service

```bash
kubectl get svc symfony-demo -n s78-lab
kubectl get svc symfony-demo -n s78-lab -o yaml
```

### Conceitos importantes

No YAML do Service, distinguir:

```text
spec.ports
→ portas expostas pelo Service

spec.selector
→ labels usadas para encontrar os Pods backend

spec.clusterIP
→ endereço virtual estável atribuído ao Service
```

O `clusterIP` existir não prova que existam endpoints.

### O que observar

Registar exatamente o selector do Service. Não o corrigir ainda.

---

# 3. Comparar selector e labels

Depois de identificar o selector, comparar com as labels reais dos Pods:

```bash
kubectl get pods -n s78-lab --show-labels
```

Também é possível testar diretamente um selector:

```bash
kubectl get pods -n s78-lab -l '<CHAVE>=<VALOR>'
```

### Como interpretar

```text
-l '<CHAVE>=<VALOR>'
→ aplica ao comando o mesmo princípio de seleção por labels usado por vários objetos Kubernetes
```

O objetivo é responder com evidência:

```text
Que Pods correspondem exatamente ao selector atual do Service?
```

---

# 4. Inspecionar o EndpointSlice

```bash
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Como interpretar

```text
-l kubernetes.io/service-name=symfony-demo
→ seleciona apenas o EndpointSlice gerido para este Service

-o yaml
→ permite observar addresses, targetRef e conditions
```

Campos importantes:

```yaml
endpoints:
  - addresses:
    conditions:
      ready:
      serving:
    targetRef:
```

### O que observar

Responder:

- existem endpoints?
- quantos?
- que Pods são referenciados em `targetRef`?
- as condições `ready` e `serving` estão verdadeiras?

Um EndpointSlice sem endpoints é evidência de que o Service não encontrou backends elegíveis; não identifica, por si só, a razão.

---

# 5. Consultar Events sem assumir que haverá erro explícito

```bash
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

Um selector logicamente incorreto pode não gerar um Event evidente. Kubernetes pode estar simplesmente a cumprir uma configuração válida que não corresponde a nenhum Pod.

Esta distinção é importante:

```text
configuração sintaticamente válida
        ≠
configuração funcionalmente correta
```

---

# 6. Formular e testar a hipótese

Registar:

```text
Sintoma:

Evidência:

Hipótese:

Teste:

Causa raiz:
```

Antes da correção, o formando deve conseguir demonstrar a relação entre:

```text
selector observado
labels observadas
EndpointSlice observado
```

---

# 7. Recuperar a configuração declarativa

Depois de confirmada a causa raiz:

```bash
kubectl apply -k app/overlays/normal/
```

### O que significa

O overlay `normal` representa o estado conhecido como bom do laboratório. Em vez de editar diretamente o Service, reaplicamos a configuração declarativa validada.

---

# 8. Validar a recuperação

```bash
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get pods -n s78-lab --show-labels
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

A validação deve provar:

```text
selector do Service
      ↓ corresponde
labels dos Pods
      ↓
2 endpoints presentes
      ↓
ready=true / serving=true
```

---

## Registo do incidente

| Campo | Registo |
|---|---|
| Sintoma | |
| Deployment saudável? | |
| Pods saudáveis? | |
| Selector do Service | |
| Labels dos Pods | |
| Pods encontrados pelo selector | |
| Endpoints antes da correção | |
| Condições `ready` / `serving` | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção declarativa | |
| Evidência de recuperação | |

---

## CHECKPOINT — Incidente 2 concluído

Não avançar até ser possível demonstrar com evidência:

```text
Pods saudáveis
Service existente
selector coerente com labels
2 endpoints utilizáveis
```

E explicar sem ambiguidade:

```text
Service selector → labels dos Pods → EndpointSlices
```
