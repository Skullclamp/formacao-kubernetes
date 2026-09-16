# Incidente 1 — Rollout bloqueado: nova réplica `Running` mas não `Ready`

## Situação entregue ao formando

Após uma alteração de configuração, o Deployment inicia uma atualização. A aplicação continua parcialmente disponível, mas o rollout não termina: uma nova réplica aparece em execução e não fica pronta para receber tráfego.

A causa **não é fornecida**. O objetivo é chegar a ela através de evidência.

---

## Objetivo

Aplicar o método de troubleshooting usado ao longo da formação:

```text
Sintoma → Evidência → Hipótese → Teste → Causa raiz → Correção → Validação
```

No final, o formando deve conseguir explicar por que razão:

```text
Running ≠ Ready
```

e como uma `readinessProbe` influencia simultaneamente:

```text
Pod
 ↓
condição Ready
 ↓
EndpointSlice
 ↓
tráfego do Service

        e

Deployment
 ↓
progressão do rollout
```

---

## Conceitos a compreender antes de diagnosticar

### `Running`

`Running` indica que o Pod foi agendado e que pelo menos um container foi iniciado ou está em processo de execução. **Não significa que a aplicação esteja pronta para servir tráfego.**

### `Ready`

A condição `Ready` indica se o Pod pode ser considerado apto para receber tráfego através de Services que o selecionem.

### `readinessProbe`

A `readinessProbe` é um teste periódico usado pelo kubelet para determinar se o container está pronto para participar no serviço.

Se a probe falhar:

```text
processo pode continuar a executar
        ↓
Pod pode continuar Running
        ↓
Pod fica NotReady
        ↓
endpoint deixa de ser elegível para tráfego
```

Isto é diferente de uma `livenessProbe`, cujo objetivo é determinar se o container deve ser reiniciado.

### Rollout do Deployment

Um Deployment tenta aproximar continuamente o estado real do estado desejado. Durante uma atualização, Kubernetes cria/substitui réplicas de acordo com a estratégia definida.

Neste laboratório é usada deliberadamente:

```yaml
maxSurge: 0
maxUnavailable: 1
```

Com duas réplicas e anti-affinity obrigatória entre Workers, isto permite substituir uma réplica de cada vez sem tentar criar uma terceira réplica que não teria onde ser colocada.

Consequência importante para este incidente:

```text
uma réplica antiga pode continuar Ready
        +
uma nova réplica pode ficar NotReady
        ↓
serviço parcialmente disponível
        +
rollout bloqueado
```

---

## Regras do incidente

- Não usar `kubectl edit` para corrigir o problema.
- Não abrir imediatamente os manifests do incidente à procura da resposta.
- Recolher evidência antes de alterar configuração.
- Registar pelo menos três comandos utilizados no diagnóstico.
- Confirmar as condições `ready` dos endpoints, não apenas a existência do EndpointSlice.
- A correção deve repor a baseline declarativa conhecida como boa.

---

# 1. Confirmar o sintoma

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

### Como interpretar os comandos e flags

```text
kubectl get deployment symfony-demo
→ consulta o estado agregado do Deployment

-n s78-lab
→ limita a operação ao Namespace do laboratório

kubectl get pods
→ mostra o estado individual das réplicas

-o wide
→ acrescenta Node, IP e outros dados úteis para distinguir as réplicas

kubectl get endpointslices
→ consulta os backends atualmente associados aos Services

-l kubernetes.io/service-name=symfony-demo
→ filtra apenas o EndpointSlice pertencente ao Service symfony-demo

-o yaml
→ mostra todos os campos, incluindo conditions.ready e conditions.serving
```

### O que observar

No Deployment, distinguir:

```text
READY
UP-TO-DATE
AVAILABLE
```

Nos Pods, comparar:

```text
STATUS
READY
AGE
NODE
```

No EndpointSlice, observar especialmente:

```yaml
conditions:
  ready: true|false
  serving: true|false
```

**Pergunta:** se um Pod aparece `Running` mas o endpoint correspondente tem `ready: false`, o que é que isso prova?

---

# 2. Recolher Events

```bash
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

### O que significa

```text
get events
→ consulta acontecimentos registados pelos componentes Kubernetes

--sort-by=.lastTimestamp
→ ordena cronologicamente pelo instante mais recente conhecido do Event
```

Os Events podem revelar problemas de scheduling, probes, imagens ou lifecycle, mas **a ausência de um Event explícito não prova ausência de problema**.

---

# 3. Inspecionar a réplica afetada

Identificar primeiro o Pod que não está `Ready`:

```bash
kubectl get pods -n s78-lab
```

Depois:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
```

Se necessário:

```bash
kubectl logs <NOVO_POD> -n s78-lab
```

### Como interpretar

`kubectl describe pod` combina vários tipos de evidência num único output:

```text
estado dos containers
imagem utilizada
probes configuradas
condições do Pod
Events associados
```

`kubectl logs` mostra a saída produzida pela aplicação. É útil para distinguir, por exemplo:

```text
aplicação arrancou mas não está Ready
        ≠
aplicação terminou com erro
```

### Questões de análise

- O container está efetivamente em execução?
- Qual é a condição `Ready`?
- Existe uma probe configurada?
- Que tipo de probe é?
- Que endpoint/porta é testado?
- O `describe` mostra falhas repetidas?
- Os logs indicam falha da aplicação ou a aplicação parece estar funcional?

Não saltar diretamente da primeira mensagem de erro para a causa raiz. Formular uma hipótese e procurar um teste que a confirme ou rejeite.

---

# 4. Formular e testar a hipótese

Registar explicitamente:

```text
Sintoma:

Evidência:

Hipótese:

Teste que confirma/rejeita a hipótese:
```

Uma hipótese só deve ser promovida a **causa raiz** quando existir evidência suficiente.

---

# 5. Recuperar a baseline declarativa

Depois de identificada a causa raiz, repor a configuração conhecida como boa:

```bash
kubectl apply -k app/overlays/normal/

kubectl rollout status deployment/symfony-demo \
  -n s78-lab \
  --timeout=180s
```

### Como interpretar

```text
apply -k app/overlays/normal/
→ renderiza e aplica o overlay Kustomize conhecido como bom

rollout status deployment/symfony-demo
→ acompanha a convergência do Deployment

--timeout=180s
→ termina com erro se a convergência não for observada no prazo indicado
```

Não considerar a recuperação concluída apenas porque `apply` terminou sem erro.

---

# 6. Validar a recuperação

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

A validação deve demonstrar:

```text
Deployment  → 2/2 Ready
Pods        → 2 × Running / Ready
Endpoints   → 2 × ready=true
Rollout     → concluído
```

---

## Registo do incidente

| Campo | Registo |
|---|---|
| Sintoma | |
| Estado do rollout | |
| Réplica antiga disponível? | |
| Nova réplica `Running`? | |
| Nova réplica `Ready`? | |
| Condições dos endpoints | |
| Evidência principal | |
| Hipótese | |
| Teste | |
| Causa raiz | |
| Correção declarativa | |
| Evidência de recuperação | |

---

## CHECKPOINT — Incidente 1 concluído

Não avançar enquanto não for possível demonstrar com evidência:

```text
2 réplicas Running
2 réplicas Ready
2 endpoints ready=true
rollout concluído
```

E explicar:

```text
Running ≠ Ready

readiness
   ↓
protege o tráfego
   +
protege a progressão do rollout
```
