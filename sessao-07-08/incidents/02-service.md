# Incidente 2 — Service existente, mas sem backends

## Situação

Os Pods estão `Running/Ready` e o Service existe, mas não existem backends utilizáveis.

## Objetivo

Compreender:

```text
Service existente ≠ Service com backends
```

E provar a relação:

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
```

## Introduzir a falha

```bash
kubectl apply -k app/overlays/incident-service/
```

## Observar

```bash
kubectl get pods -n s78-lab --show-labels
kubectl get svc symfony-demo -n s78-lab -o yaml
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Evidência esperada

- os Pods Symfony permanecem `Running/Ready` com `app=symfony-demo`;
- o Service mantém-se criado, mas o selector passa a `app=symfony-demo-inexistente`;
- o selector não encontra Pods;
- o EndpointSlice fica sem endpoints utilizáveis (`endpoints: null` no cenário validado).

## Testar a hipótese

Depois de identificar o selector configurado no Service:

```bash
kubectl get pods -n s78-lab -l <CHAVE>=<VALOR>
```

Perguntas orientadoras:

- Os Pods estão realmente `Ready`?
- O selector corresponde às labels?
- Existem addresses no EndpointSlice?
- O problema está nos Pods ou na seleção feita pelo Service?

## Recuperar

```bash
kubectl apply -k app/overlays/normal/
kubectl get svc symfony-demo -n s78-lab \
  -o jsonpath='selector={.spec.selector.app}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

Validar a cadeia:

```text
selector correto
      ↓
labels correspondentes
      ↓
EndpointSlice preenchido
      ↓
backends utilizáveis
```
