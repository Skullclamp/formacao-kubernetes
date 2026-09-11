# Laboratório 2 — Kubernetes Básico

## Objetivo

Consultar o ambiente Kubernetes, identificar o contexto ativo, criar um Namespace e um Pod através de YAML e utilizar labels e selectors.

## 1. Consultar o ambiente

```bash
kubectl get nodes
kubectl get namespaces
kubectl config current-context
```

Confirme que o cluster responde e identifique o contexto em utilização.

## 2. Criar o Namespace

```bash
kubectl create namespace formacao
kubectl get ns
```

Confirme que o Namespace `formacao` foi criado.

## 3. Analisar o manifest do Pod

Ficheiro utilizado:

```text
manifests/pod-demo.yaml
```

Antes de aplicar, identifique:

- `apiVersion`;
- `kind`;
- nome do recurso;
- Namespace;
- labels;
- imagem utilizada;
- campo que descreve o estado pretendido.

## 4. Criar o Pod

A partir da diretoria `sessao-01`:

```bash
kubectl apply -f manifests/pod-demo.yaml
kubectl get pods -n formacao
```

## 5. Consultar labels

```bash
kubectl get pods -n formacao --show-labels
```

## 6. Utilizar um selector

```bash
kubectl get pods -n formacao -l app=web
```

Compare o resultado com a lista completa de Pods.

## 7. Limpeza

```bash
kubectl delete namespace formacao
```

Ao remover o Namespace são também removidos os recursos criados dentro dele neste laboratório.

## Resultado esperado

- cluster consultado;
- contexto ativo identificado;
- Namespace criado;
- Pod criado através de YAML;
- labels observadas;
- selector validado;
- recursos removidos no final.
