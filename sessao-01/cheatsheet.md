# Cheatsheet — Sessão 1

## 1. Conceitos essenciais de containers

| Conceito | Ideia principal |
|---|---|
| **VM** | Ambiente virtualizado com sistema operativo convidado próprio |
| **Container** | Ambiente isolado para executar uma aplicação, partilhando o kernel do host |
| **Imagem** | Base utilizada para criar uma ou várias instâncias de containers |
| **Container Runtime** | Componente responsável pela execução dos containers |
| **Registry** | Armazena e disponibiliza imagens |
| **Volume** | Permite separar os dados do ciclo de vida do container |

```text
Imagem
  ↓
Runtime
  ↓
Container
  ↓
Aplicação
```

Ideias a reter:

```text
Container ≠ Imagem
Container ≠ Máquina Virtual
Dados ≠ ciclo de vida do Container
```

## 2. Docker — comandos essenciais

```bash
docker run --name web-demo -d nginx
docker ps
docker logs web-demo
docker stop web-demo
docker rm web-demo
```

### Volumes

```bash
docker volume create dados-demo
docker volume ls
```

## 3. Conceitos essenciais de Kubernetes

| Conceito | Ideia principal |
|---|---|
| **Kubernetes** | Plataforma de orquestração de aplicações containerizadas |
| **Cluster** | Conjunto de recursos Kubernetes geridos como uma unidade |
| **Control Plane** | Gere e coordena o estado do cluster |
| **Worker Node** | Executa os workloads |
| **Pod** | Unidade básica onde Kubernetes executa containers |
| **Namespace** | Organiza e separa logicamente recursos |
| **Label** | Metadado chave-valor associado a um recurso |
| **Selector** | Seleciona recursos com base nas labels |
| **Annotation** | Metadado adicional não utilizado para seleção |
| **kubectl** | Ferramenta de linha de comandos para interagir com o cluster |
| **kubeconfig** | Configuração de acesso a clusters, utilizadores e contextos |

```text
kubectl
   ↓
kubeconfig
   ↓
Context
   ↓
Cluster / User / Namespace
```

## 4. kubectl — consulta rápida

```bash
kubectl cluster-info
kubectl get nodes
kubectl get namespaces
kubectl config current-context
kubectl config get-contexts
```

### Criar e consultar recursos

```bash
kubectl create namespace formacao
kubectl get ns

kubectl apply -f manifests/pod-demo.yaml
kubectl get pods -n formacao

kubectl get pods -n formacao --show-labels
kubectl get pods -n formacao -l app=web
```

### Limpeza

```bash
kubectl delete namespace formacao
```

## 5. Anatomia mínima de um manifest YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-demo
  namespace: formacao
  labels:
    app: web
spec:
  containers:
    - name: web
      image: nginx
```

```text
apiVersion → versão da API
kind       → tipo de recurso
metadata   → identificação e metadados
spec       → estado pretendido
```

## 6. Primeiras verificações quando algo não funciona

### Docker

```bash
docker ps
docker logs <container>
```

### Kubernetes

```bash
kubectl get pods -n <namespace>
kubectl get pods -n <namespace> --show-labels
kubectl describe pod <pod> -n <namespace>
```
