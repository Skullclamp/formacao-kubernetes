# Preparação do cluster — Sessão 10

## Ambiente em que o laboratório foi validado

No ensaio de 16/09/2026 foram observados:

- Kubernetes `v1.36.4`;
- 1 control-plane + 2 workers Ready;
- Calico como CNI com enforcement de NetworkPolicy;
- CoreDNS operacional;
- StorageClass `local-path` (`WaitForFirstConsumer`), sem StorageClass por omissão;
- IngressClass `traefik`;
- PostgreSQL 16;
- Metrics Server funcional após correção de preparação do laboratório.

Estes dados descrevem o **cluster de ensaio** e não devem ser assumidos noutro ambiente sem confirmação.

## Checklist antes da aula

```bash
kubectl get nodes -o wide
kubectl get storageclass
kubectl get ingressclass
kubectl -n kube-system get pods
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

Confirmar ainda:

- acesso às imagens `1.1.0` e `1.2.0-rc1`;
- Secret `postgres-credentials` preparado em cada namespace/ambiente necessário;
- espaço/memória suficientes para até 5 formandos;
- relógio sincronizado em todos os nodes;
- Helm e `kubectl kustomize` disponíveis se forem executadas as micropráticas M6.

## Metrics Server — particularidade do cluster de ensaio

O Metrics Server falhou inicialmente ao contactar os kubelets porque os certificados de serving não continham os IPs nos SANs.

No laboratório foi usado, apenas como workaround:

```text
--kubelet-insecure-tls
```

Antes de repetir esse workaround, confirmar nos logs do Metrics Server que a causa é efetivamente a mesma. Em produção, a solução recomendada é corrigir os certificados/PKI dos kubelets; não normalizar a desativação da validação TLS.

Depois da correção, validar obrigatoriamente:

```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
kubectl top pods -A
```

## Tempo / Events

Durante o ensaio apareceram Events com:

```text
AGE <invalid>
```

Foi também observada sincronização temporal incompleta. Antes da formação:

```bash
timedatectl
systemctl list-units --type=service --state=running | grep -Ei 'chrony|chronyd|ntp|timesync' || true
```

Identificar o daemon realmente instalado e corrigir a sincronização. Se existir reboot pendente, executá-lo numa janela de manutenção e voltar a validar nodes, API e métricas.

## Turma até 5 formandos

Para reduzir pressão no cluster:

- usar um namespace por formando ou por par;
- escalonar no tempo o gerador de carga do HPA;
- remover as releases temporárias de Kustomize/Helm assim que cada microprática terminar;
- não executar simultaneamente 5 geradores de carga sem observar primeiro `kubectl top nodes`.
