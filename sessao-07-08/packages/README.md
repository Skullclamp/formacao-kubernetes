# Pacotes externos validados

Esta diretoria guarda dependências externas usadas na preparação do laboratório das **Sessões 7 e 8**.

A versão de `kube-prometheus-stack` validada no cluster de referência é:

```text
91.4.1
```

## Preparação pelo formador — antes das sessões

A instalação da monitorização **não faz parte do tempo de aula**. Para preservar as 4 horas do laboratório para troubleshooting, resiliência, Helm, Kustomize e reconciliação, o formador deve preparar previamente o Prometheus Operator.

```bash
cd ~/formacao-kubernetes/sessao-07-08
chmod +x monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1

helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
```

Validar:

```bash
helm status monitoring -n monitoring
kubectl get pods -n monitoring
kubectl get crd prometheusrules.monitoring.coreos.com
```

Depois executar o precheck do laboratório das Sessões 7 e 8.

> O download do chart não constitui validação. A versão deve ser testada previamente no cluster utilizado na formação.
