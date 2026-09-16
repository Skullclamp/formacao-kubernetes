# Incidente 4 — Upgrade Helm defeituoso e rollback

## Situação

A aplicação já é gerida pela release Helm `symfony-lab`. Uma nova candidata é aplicada, mas o rollout não fica operacional.

## Objetivo

Observar:

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

## Health gate

```bash
helm list -n s7-lab
helm history symfony-lab -n s7-lab
kubectl get pods -n s7-lab -o wide
kubectl get endpointslices -n s7-lab
```

Identificar a revisão atualmente conhecida como boa.

## Aplicar a candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s7-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o upgrade não conclua com sucesso.

## Recolher evidência

```bash
helm status symfony-lab -n s7-lab
helm history symfony-lab -n s7-lab
kubectl get pods -n s7-lab -o wide
kubectl get events -n s7-lab --sort-by=.lastTimestamp
```

Identificar o Pod novo:

```bash
kubectl describe pod <NOVO_POD> -n s7-lab
kubectl get pod <NOVO_POD> -n s7-lab \
  -o jsonpath='{.spec.containers[0].image}{"\n"}'
```

Perguntas orientadoras:

- Foi criada uma nova revision?
- Qual é o estado do novo Pod?
- Que Event é persistente?
- Qual a imagem realmente aplicada?
- Existe ainda alguma réplica anterior utilizável?

## Rollback

Consultar novamente o histórico:

```bash
helm history symfony-lab -n s7-lab
```

Executar o rollback para a revisão conhecida como boa:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s7-lab \
  --wait \
  --timeout 3m
```

## Validar

```bash
helm history symfony-lab -n s7-lab
kubectl rollout status deployment/symfony-demo \
  -n s7-lab --timeout=180s
kubectl get pods -n s7-lab
```

Mensagem-chave:

```text
rollback recupera conteúdo de uma revisão anterior
mas cria uma nova revisão no histórico
```

E:

```text
Chart ≠ Release ≠ Revision
```
