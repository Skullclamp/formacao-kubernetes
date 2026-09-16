# Pacotes externos pré-validados

Esta diretoria destina-se a guardar dependências externas preparadas **antes da formação**.

Para o laboratório de monitorização, o formador deve colocar aqui uma versão previamente testada do chart `kube-prometheus-stack`.

Exemplo de preparação:

```bash
chmod +x monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh <VERSAO_VALIDADA>
```

Resultado esperado:

```text
packages/
└── kube-prometheus-stack-<VERSAO_VALIDADA>.tgz
```

Durante a sessão, instalar a partir do pacote local para reduzir a dependência da Internet:

```bash
helm install monitoring \
  ./packages/kube-prometheus-stack-<VERSAO_VALIDADA>.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml
```

> A versão não é fixada neste repositório: deve ser escolhida, testada e congelada pelo formador para o ambiente concreto da formação.
