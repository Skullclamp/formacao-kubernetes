# Cheatsheet — Sessão 1

Referência rápida aos comandos e estruturas utilizados na sessão.

## Docker

| Operação | Comando |
|---|---|
| Executar container | `docker run --name web-demo -d nginx` |
| Listar containers em execução | `docker ps` |
| Consultar logs | `docker logs web-demo` |
| Parar container | `docker stop web-demo` |
| Remover container | `docker rm web-demo` |
| Criar volume | `docker volume create dados-demo` |
| Listar volumes | `docker volume ls` |

## Podman

| Operação | Comando |
|---|---|
| Executar container | `podman run --name web-demo -d nginx` |
| Listar containers em execução | `podman ps` |
| Consultar logs | `podman logs web-demo` |
| Parar container | `podman stop web-demo` |
| Remover container | `podman rm web-demo` |

## kubectl — cluster e contextos

| Operação | Comando |
|---|---|
| Informação do cluster | `kubectl cluster-info` |
| Listar nodes | `kubectl get nodes` |
| Listar namespaces | `kubectl get namespaces` |
| Contexto atual | `kubectl config current-context` |
| Listar contextos | `kubectl config get-contexts` |
| Alterar contexto | `kubectl config use-context <contexto>` |

## kubectl — recursos

| Operação | Comando |
|---|---|
| Criar namespace | `kubectl create namespace formacao` |
| Listar namespaces | `kubectl get ns` |
| Aplicar manifest | `kubectl apply -f manifests/pod-demo.yaml` |
| Listar Pods | `kubectl get pods -n formacao` |
| Mostrar labels | `kubectl get pods -n formacao --show-labels` |
| Filtrar por label | `kubectl get pods -n formacao -l app=web` |
| Detalhar Pod | `kubectl describe pod <pod> -n <namespace>` |
| Remover namespace | `kubectl delete namespace formacao` |

## YAML — estrutura base

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
    environment: formacao
spec:
  containers:
    - name: web
      image: nginx
```

## Campos mais utilizados

| Campo | Exemplo |
|---|---|
| `apiVersion` | `v1` |
| `kind` | `Pod` |
| `metadata.name` | `web-demo` |
| `metadata.namespace` | `formacao` |
| `metadata.labels` | `app: web` |
| `spec.containers[].name` | `web` |
| `spec.containers[].image` | `nginx` |

## Labels e selectors

```yaml
labels:
  app: web
  environment: formacao
```

```bash
kubectl get pods -n formacao -l app=web
kubectl get pods -n formacao -l environment=formacao
```

## Verificações rápidas

### Docker

```bash
docker ps
docker logs <container>
```

### Kubernetes

```bash
kubectl get nodes
kubectl config current-context
kubectl get pods -n <namespace>
kubectl describe pod <pod> -n <namespace>
```
