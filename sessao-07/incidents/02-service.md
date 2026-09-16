# Incidente 2 — Pods saudáveis, Service sem resposta

## Como utilizar este incidente

Este bloco é realizado em **modo acompanhado**. O formador apresenta o sintoma, pede observações concretas e conduz a turma na interpretação da cadeia `Service → selector → labels → EndpointSlice`.

O objetivo não é adivinhar rapidamente a causa, mas perceber como provar cada hipótese com os objetos reais do cluster.

---

## Situação

Os Pods da aplicação estão `Running` e `Ready`. O objeto `Service` existe, mas os pedidos enviados através do Service não chegam à aplicação.

## Objetivo pedagógico

Compreender que:

```text
Service existente ≠ Service com backends utilizáveis
```

E observar a relação:

```text
Service selector
      ↓
labels dos Pods
      ↓
EndpointSlice
      ↓
backends do Service
```

---

# 1. Conceitos antes de executar comandos

## Service

Um `Service` fornece um ponto de acesso estável a um conjunto dinâmico de Pods. Os Pods podem ser recriados com novos IPs; o Service mantém um ponto lógico estável.

## Labels

Labels são pares chave/valor associados aos objetos Kubernetes. Permitem organizar e selecionar recursos.

Exemplo conceptual:

```yaml
labels:
  app: minha-app
  role: web
```

## Selector

Um Service normalmente escolhe os Pods através de um selector.

Exemplo conceptual:

```yaml
selector:
  app: minha-app
```

A correspondência entre selector e labels é exata para as chaves usadas.

## EndpointSlice

Os controladores Kubernetes mantêm EndpointSlices com os endpoints que o Service pode usar.

Um Service pode existir sem endpoints se nenhum Pod corresponder ao selector.

---

# 2. Observar o estado — executar em conjunto

```bash
kubectl get pods -n s7-lab --show-labels
kubectl get svc symfony-demo -n s7-lab -o yaml
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

## Comandos e flags

```text
--show-labels
→ mostra as labels dos Pods no output

kubectl get svc ... -o yaml
→ mostra a definição completa do Service, incluindo spec.selector

-l kubernetes.io/service-name=symfony-demo
→ seleciona apenas o EndpointSlice associado ao Service em estudo

-o yaml
→ permite observar endpoints e respetivas condições
```

## Observação guiada

O formador pede à turma para comparar lado a lado:

```text
selector do Service
        ↕
labels dos Pods
        ↓
conteúdo do EndpointSlice
```

Perguntas orientadoras:

```text
Os Pods estão realmente Ready?
Que selector está definido no Service?
Existe pelo menos um Pod cujas labels correspondem ao selector?
O EndpointSlice contém addresses?
```

### Checkpoint acompanhado

Não avançar enquanto a turma não conseguir explicar por que um objeto Service pode existir sem encaminhar tráfego para qualquer Pod.

---

# 3. Testar a hipótese

Se a hipótese apontar para incompatibilidade entre selector e labels, confirmar diretamente com um selector equivalente ao observado no Service.

Exemplo do método:

```bash
kubectl get pods -n s7-lab -l <CHAVE>=<VALOR>
```

## Interpretação

```text
-l <selector>
→ pede à API apenas os objetos cujas labels correspondem ao selector indicado
```

Este teste transforma uma hipótese numa prova observável: se o selector não devolver Pods, o Service também não os poderá usar como backends através desse selector.

---

# 4. Recuperar a baseline declarativa

A correção é feita reaplicando a configuração conhecida como boa:

```bash
kubectl apply -k app/overlays/normal/
```

Depois validar:

```bash
kubectl get svc symfony-demo -n s7-lab -o yaml
kubectl get pods -n s7-lab --show-labels
kubectl get endpointslices -n s7-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

O formador volta a pedir a comparação:

```text
selector correto
      ↓
labels correspondentes
      ↓
EndpointSlice preenchido
```

---

# 5. Validação final acompanhada

O incidente só termina quando existir evidência de:

```text
Pods Symfony      → Running / Ready
Service           → selector coerente
EndpointSlice     → 2 endpoints
conditions.ready  → true nos endpoints utilizáveis
```

## Registo na folha de evidências

| Campo | Registo |
|---|---|
| Sintoma observado | |
| Selector observado | |
| Labels observadas | |
| Evidência no EndpointSlice | |
| Hipótese formulada | |
| Teste efetuado | |
| Causa raiz identificada | |
| Correção aplicada | |
| Evidência final | |

## Síntese a consolidar

```text
Service
  não descobre Pods pelo nome

Service selector
      ↓
labels dos Pods
      ↓
EndpointSlices
      ↓
tráfego utilizável
```
