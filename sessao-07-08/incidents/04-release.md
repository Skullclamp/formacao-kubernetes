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
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
```

Confirmar que a release está `deployed`, o Deployment está `2/2` e identificar a revisão atualmente conhecida como boa.

## Aplicar a candidata

```bash
helm upgrade symfony-lab \
  ./helm/app-lab \
  -n s78-lab \
  -f helm/values/values-broken.yaml \
  --wait \
  --timeout 90s
```

É esperado que o upgrade termine por timeout e que a nova revisão fique `failed`.

## Recolher evidência

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
```

Identificar o Pod não Ready e aprofundar:

```bash
kubectl describe pod <NOVO_POD> -n s78-lab
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
```

## Evidência esperada

Na variante agora adaptada para as Sessões 7 e 8, a candidata altera a imagem para:

```text
registry.invalid/s78/symfony-demo:1.0.0
```

É esperado observar:

- release Helm com nova revisão em `failed`;
- Deployment temporariamente em `1/2`;
- uma réplica anterior saudável ainda utilizável;
- novo Pod em `ErrImagePull`/`ImagePullBackOff`;
- `describe` com erro de resolução/pull do registry inválido;
- Deployment a declarar a imagem inválida.

Um `FailedScheduling` transitório devido à anti-affinity pode surgir antes de o Pod ser colocado no segundo Worker. Se o Pod acabar agendado e a falha persistente for `ImagePullBackOff`, a causa raiz é a imagem/registry inválido, não o scheduling transitório.

Perguntas orientadoras:

- Foi criada uma nova revision?
- Qual é o estado da release?
- Qual é o estado do novo Pod?
- Que Event é persistente?
- Qual a imagem realmente declarada no Deployment?
- Existe ainda alguma réplica anterior utilizável?

## Rollback

Consultar novamente o histórico:

```bash
helm history symfony-lab -n s78-lab
```

Executar o rollback para a revisão conhecida como boa:

```bash
helm rollback symfony-lab <REVISAO_BOA> \
  -n s78-lab \
  --wait \
  --timeout 180s
```

> O rollback recupera o conteúdo de uma revisão anterior, mas cria uma **nova revisão**. Não faz o número da revisão atual voltar atrás.

## Validar

```bash
helm status symfony-lab -n s78-lab
helm history symfony-lab -n s78-lab
kubectl rollout status deployment/symfony-demo \
  -n s78-lab --timeout=180s
kubectl get deployment symfony-demo -n s78-lab
kubectl get pods -n s78-lab -o wide
kubectl get deployment symfony-demo -n s78-lab \
  -o jsonpath='image={.spec.template.spec.containers[0].image}{"\n"}'
kubectl get endpointslices -n s78-lab \
  -l kubernetes.io/service-name=symfony-demo \
  -o yaml
```

A recuperação só fica demonstrada quando:

- a release regressa a `deployed`;
- o Deployment está `2/2`;
- a imagem regressa a `ghcr.io/skullclamp/symfony-demo:1.0.0`;
- os dois Pods estão `1/1 Running`;
- os dois endpoints estão `ready: true`.

Mensagem-chave:

```text
rollback recupera conteúdo de uma revisão anterior
mas cria uma nova revisão no histórico
```

E:

```text
Chart ≠ Release ≠ Revision
```
