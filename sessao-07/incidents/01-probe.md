# Incidente 1 — Rollout bloqueado: nova réplica `Running` mas não `Ready`

## Como utilizar este incidente

Este incidente faz parte de um **laboratório acompanhado**. Não é uma ficha autónoma para o formando resolver sozinho.

O formador conduz a turma passo a passo:

```text
observar
  ↓
interpretar em conjunto
  ↓
formular uma hipótese
  ↓
testar a hipótese
  ↓
identificar a causa raiz
  ↓
corrigir
  ↓
validar
```

A causa não é revelada no início, para permitir praticar troubleshooting, mas o formador orienta a recolha e interpretação da evidência em cada etapa.

---

## Situação

Após uma alteração de configuração, o Deployment inicia uma atualização. A aplicação continua parcialmente disponível, mas o rollout não termina: uma nova réplica aparece em execução e não fica pronta para receber tráfego.

## Objetivo pedagógico

Compreender e observar, no cluster real:

```text
Running ≠ Ready
```

E relacionar:

```text
readinessProbe
      ↓
condição Ready do Pod
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

# 1. Conceitos antes de executar comandos

## `Running`

`Running` indica que o Pod foi agendado e que o container está em execução ou iniciou a sua execução. Não significa que a aplicação esteja preparada para receber tráfego.

## `Ready`

`Ready` indica se o Pod está apto a participar no serviço. Um Pod pode estar `Running` e simultaneamente `NotReady`.

## `readinessProbe`

A `readinessProbe` é executada pelo kubelet para determinar se a aplicação está pronta para receber pedidos.

Se a probe falhar:

```text
container continua em execução
        ↓
Pod pode continuar Running
        ↓
Pod fica NotReady
        ↓
endpoint fica não elegível para tráfego
```

Isto é diferente da `livenessProbe`: uma falha de liveness pode levar ao reinício do container.

## Estratégia do Deployment

Neste laboratório o Deployment usa:

```yaml
maxSurge: 0
maxUnavailable: 1
```

Com dois Workers e anti-affinity obrigatória, esta estratégia substitui uma réplica de cada vez. Durante uma atualização problemática pode permanecer uma réplica antiga disponível enquanto a nova réplica não fica pronta.

---

# 2. Observar o sintoma — executar em conjunto

```bash
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
kubectl get events -n s78-lab --sort-by=.lastTimestamp
```

## O que significam os comandos e flags

```text
kubectl get deployment
→ mostra o estado desejado e disponível do Deployment

-n s78-lab
→ executa a consulta no Namespace do laboratório

kubectl get pods -o wide
→ acrescenta IP e Node; ajuda a identificar a réplica antiga e a nova

-l kubernetes.io/service-name=symfony-demo
→ filtra apenas o EndpointSlice pertencente ao Service Symfony

-o yaml
→ permite observar condições detalhadas dos endpoints

--sort-by=.lastTimestamp
→ ordena os Events temporalmente para facilitar a análise do incidente
```

## O que o formador pede para observar

Em conjunto, identificar:

```text
Deployment → quantas réplicas Ready/Available?
Pod antigo → continua Ready?
Pod novo   → Running? Ready?
Endpoint   → ready=true ou ready=false?
Events     → existe evidência relacionada com probes ou rollout?
```

### Checkpoint acompanhado

Antes de avançar, a turma deve conseguir explicar por que razão `Running` não chega para concluir que a aplicação está saudável.

---

# 3. Recolher evidência do Pod afetado

O formador identifica com a turma o Pod novo e define a variável:

```bash
POD=<NOVO_POD>
```

Depois executar:

```bash
kubectl describe pod "$POD" -n s78-lab
kubectl logs "$POD" -n s78-lab
```

## Como interpretar

```text
kubectl describe pod
→ mostra estado, probes, condições, imagem, Node e Events associados ao Pod

kubectl logs
→ mostra o stdout/stderr da aplicação; serve para distinguir problema da aplicação de problema de prontidão/configuração
```

O formador orienta a turma a procurar evidência que explique por que o Pod está `Running` mas não `Ready`.

---

# 4. Formular e testar a hipótese

A turma regista uma hipótese baseada na evidência recolhida.

Perguntas guiadas pelo formador:

```text
A aplicação arrancou?
A readiness probe está a responder com sucesso?
O endpoint testado pela probe existe?
O problema está no processo ou apenas na prontidão?
O Service está corretamente a excluir a réplica não pronta?
```

Só depois de existir evidência suficiente se identifica a causa raiz.

---

# 5. Recuperar a baseline declarativa

A correção do laboratório não é feita com `kubectl edit`. Reaplica-se o estado conhecido como bom:

```bash
kubectl apply -k app/overlays/normal/
kubectl rollout status deployment/symfony-demo \
  -n s78-lab \
  --timeout=180s
```

Depois validar:

```bash
kubectl get pods -n s78-lab -o wide
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Flags importantes

```text
-k app/overlays/normal/
→ aplica o resultado da configuração Kustomize dessa diretoria

rollout status
→ acompanha a convergência do Deployment

--timeout=180s
→ limita a espera a 180 segundos
```

---

# 6. Validação final acompanhada

O incidente só termina quando a turma confirmar:

```text
Deployment          → 2/2 Ready
Pods Symfony        → 2 × Running / Ready
EndpointSlice       → 2 endpoints ready=true
rollout             → concluído com sucesso
```

## Registo na folha de evidências

Registar apenas a evidência essencial observada durante a execução acompanhada:

| Campo | Registo |
|---|---|
| Sintoma observado | |
| Evidência principal | |
| Hipótese formulada | |
| Teste utilizado | |
| Causa raiz identificada | |
| Correção aplicada | |
| Evidência após recuperação | |

## Síntese a consolidar

```text
Running ≠ Ready
readiness protege o tráfego
readiness também influencia o rollout
uma correção só está concluída depois de validada
```
