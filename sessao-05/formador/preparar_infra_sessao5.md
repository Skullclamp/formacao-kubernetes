# Preparação da infraestrutura — Sessão 5

Este guia destina-se ao **formador**. Prepara os componentes que devem existir antes do laboratório manual do formando.

Baseline validada:

```text
Kubernetes:               1.36.4
Control Plane:            k8s-cp-01
Workers:                  k8s-wk-01, k8s-wk-03
local-path-provisioner:   v0.0.37
Gateway API:              v1.6.1
Helm:                     v3.22.0
Traefik Chart:            41.5.0
Traefik Proxy:            v3.7.13
HTTP NodePort:            30080
HTTPS NodePort:           30443
Gateway listener HTTP:    8000
```

Todos os comandos desta preparação são executados no `k8s-cp-01`.

---

## 1. Pré-flight

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Esperado:

```text
k8s-cp-01  Ready
k8s-wk-01  Ready
k8s-wk-03  Ready
```

O Control Plane deve manter o taint `NoSchedule`:

```bash
kubectl get node k8s-cp-01 -o jsonpath='{.spec.taints}{"\n"}'
```

---

## 2. Instalar Local Path Provisioner

```bash
kubectl apply -f \
https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.37/deploy/local-path-storage.yaml
```

Aguardar:

```bash
kubectl wait \
  -n local-path-storage \
  --for=condition=Ready \
  pod \
  -l app=local-path-provisioner \
  --timeout=180s
```

Validar:

```bash
kubectl get pods -n local-path-storage -o wide
kubectl get storageclass local-path
kubectl get storageclass local-path -o yaml
```

Confirmar:

```text
provisioner: rancher.io/local-path
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

> `local-path-provisioner` é um external provisioner. Não deve ser apresentado como driver CSI.

---

## 3. Instalar Gateway API CRDs

```bash
kubectl apply --server-side=true -f \
https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml
```

Validar:

```bash
kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

---

## 4. Instalar Helm 3 quando necessário

Confirmar primeiro:

```bash
helm version
```

Se Helm 3 não estiver instalado:

```bash
curl -fsSL -o /tmp/get_helm.sh \
https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3

chmod 700 /tmp/get_helm.sh
sudo /tmp/get_helm.sh
```

Validar:

```bash
helm version
```

A baseline validada utilizou Helm `v3.22.0`.

---

## 5. Adicionar repositório Traefik

```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

---

## 6. Instalar Traefik

```bash
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --version 41.5.0 \
  --set service.spec.type=NodePort \
  --set ports.web.nodePort=30080 \
  --set ports.websecure.nodePort=30443 \
  --set ingressClass.enabled=true \
  --set ingressClass.isDefaultClass=false \
  --set ingressClass.name=traefik \
  --set providers.kubernetesIngress.enabled=true \
  --set providers.kubernetesIngress.ingressClass=traefik \
  --set providers.kubernetesGateway.enabled=true \
  --set gateway.enabled=false \
  --set gatewayClass.enabled=true \
  --set gatewayClass.name=traefik
```

Aguardar:

```bash
kubectl wait \
  -n traefik \
  --for=condition=Available \
  deployment/traefik \
  --timeout=300s
```

Validar:

```bash
kubectl get pods -n traefik -o wide
kubectl get svc -n traefik
kubectl get ingressclass traefik
kubectl get gatewayclass traefik
```

Esperado:

```text
Traefik Pod       1/1 Running
Service           NodePort
HTTP              80:30080/TCP
HTTPS             443:30443/TCP
IngressClass      traefik
GatewayClass      traefik / Accepted=True
```

Confirmar os argumentos do Deployment:

```bash
kubectl get deployment traefik \
  -n traefik \
  -o jsonpath='{.spec.template.spec.containers[0].args}' ; echo
```

Procurar:

```text
--entryPoints.web.address=:8000/tcp
--entryPoints.websecure.address=:8443/tcp
--providers.kubernetesingress
--providers.kubernetesgateway
```

---

## 7. Porque `gateway.enabled=false`?

A infraestrutura cria a `GatewayClass traefik`, mas não cria antecipadamente o Gateway do exercício.

```text
formador prepara GatewayClass
        ↓
formando interpreta GatewayClass
        ↓
formando cria Gateway
        ↓
formando cria HTTPRoute
```

Isto preserva o objetivo pedagógico da Sessão 5.

---

## 8. Teste final antes da formação

Executar:

```bash
chmod +x validar_lab_sessao5.sh
./validar_lab_sessao5.sh
```

A execução de referência desta baseline terminou com:

```text
Total de verificações: 48
OK:                   48
Avisos:                0
Falhas:                0

RESULTADO GLOBAL: APROVADO
```

Só depois desta validação deve o ambiente ser considerado pronto para o laboratório dos formandos.
