# Pacotes externos validados

Esta diretoria guarda dependências externas utilizadas no laboratório.

Para a Sessão 7, a versão de `kube-prometheus-stack` validada no cluster real da formação é:

```text
91.4.1
```

## Download pelos formandos no CP1

Depois de descarregar o repositório, cada formando prepara o pacote com:

```bash
cd ~/formacao-kubernetes/sessao-07
chmod +x monitoring/prepare-chart.sh
./monitoring/prepare-chart.sh 91.4.1
```

Resultado esperado:

```text
packages/
├── README.md
└── kube-prometheus-stack-91.4.1.tgz
```

Confirmar:

```bash
ls -lh packages/kube-prometheus-stack-91.4.1.tgz
helm show chart packages/kube-prometheus-stack-91.4.1.tgz
```

Durante o laboratório, instalar sempre a partir do pacote local:

```bash
helm upgrade --install monitoring \
  packages/kube-prometheus-stack-91.4.1.tgz \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/values-lab.yaml \
  --wait \
  --timeout 10m
```

> Se a sessão tiver de decorrer sem acesso à Internet, o formador deve disponibilizar previamente o ficheiro `kube-prometheus-stack-91.4.1.tgz`. O download não substitui a validação: esta versão foi testada no cluster de referência antes de ser adotada para o laboratório.
