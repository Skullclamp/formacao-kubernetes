# Validação técnica — Sessões 9 e 10

## Resultado global

**Pacote consolidado após validação runtime real do laboratório principal e revalidação runtime das micropráticas M6.**

Data do ensaio de referência do percurso principal: **16/09/2026**.

## Evidência runtime obtida

| Bloco | Resultado | Evidência observada |
|---|---|---|
| PostgreSQL | ✅ | StatefulSet `postgres` 1/1, PVC `Bound`, `pg_isready` a aceitar ligações |
| Symfony estável | ✅ | Deployment 2/2, imagem `1.1.0`, `/health`, `/ready` e `/info` funcionais |
| Resources/probes | ✅ | requests/limits aplicados; liveness `/health`; readiness `/ready` |
| Metrics Server | ✅ | `kubectl top` funcional após preparação do cluster |
| HPA scale-out | ✅ | 2 → 4 → 5 réplicas com CPU acima do target |
| HPA scale-in | ✅ | 5 → 2 após estabilização; `minReplicas=2` respeitado |
| Troubleshooting | ✅ | Pod `Running` mas `NotReady`; readiness 404; recuperação após correção |
| ServiceAccount/SecurityContext | ✅ | SA dedicada; token não montado; `RuntimeDefault`; `allowPrivilegeEscalation=false` |
| NetworkPolicy | ✅ | ambos os clientes confirmados `Running/Ready`; labels `access` verificadas; mesmo Service/porta/endpoint `/health`; cliente autorizado respondeu e cliente bloqueado terminou em timeout |
| Release candidata | ✅ | `1.2.0-rc1` + readiness inválida criou nova revisão não Ready |
| Disponibilidade durante falha | ✅ | versão estável continuou a responder pelo Service |
| Rollback | ✅ | `rollout undo` restaurou `1.1.0`, `/ready` e Deployment 2/2 |
| Kustomize M6 | ✅ | DEV/PROD renderizados; diferenças de `APP_ENV`, réplicas, CPU request e nomes confirmadas; DEV aplicado com 1 réplica, `APP_ENV=dev`, CPU 50m; EndpointSlice `ready=true`/`serving=true`; cleanup sem afetar a baseline |
| Helm M6 | ✅ | `helm lint` sem falhas; Chart renderizado; release `symfony-demo-helm` instalada em revisão 1 `deployed`; Deployment 1/1, Service 80/TCP, imagem `1.1.0`, EndpointSlice `ready=true`/`serving=true`; uninstall removeu a release e preservou a baseline |

## Correções incorporadas nesta versão

- baseline M4 separado de resources/probes M5;
- PostgreSQL normalizado para `Service/StatefulSet` **`postgres`**;
- Secret normalizado para **`postgres-credentials`** sem valores reais no pacote;
- ConfigMap com `APP_ENV` e `APP_VERSION`;
- StorageClass de laboratório definida como `local-path` no manifesto PostgreSQL validado;
- Ingress de exemplo configurado com `ingressClassName: traefik`;
- Deployment Symfony usa labels `app=symfony-demo` e container `symfony`, coerentes com o ensaio;
- resources: `100m/128Mi` requests e `500m/512Mi` limits no Symfony;
- probes testadas: `/health` e `/ready`;
- HPA `autoscaling/v2`, target CPU 50%, min 2, max 5;
- gerador de carga HPA dividido em `gerar-carga.sh` e `parar-carga.sh`;
- removido o watch multi-recurso que falhou no cliente utilizado; o guião usa observação separada de HPA e Pods;
- cenário opcional de observabilidade preservado como recurso, mas retirado do percurso principal de 80 min;
- ServiceAccount é criada **antes** do patch de SecurityContext;
- validação de segurança verifica os Pods da nova revisão e a ausência do token montado;
- NetworkPolicy exige teste pré-policy, positivo e negativo pós-policy;
- os clientes da NetworkPolicy usam uma janela de execução longa e os scripts validam explicitamente Pod `Running/Ready`, labels e presença/ausência da policy antes de concluir;
- uma falha genérica do cliente bloqueado deixou de ser aceite como prova: o teste pós-policy só considera o cenário esperado quando o cliente permitido responde e o cliente bloqueado termina por timeout;
- release candidata altera imagem + readiness numa única revisão;
- rollback inclui nota sobre `kubectl apply`/`last-applied-configuration` e recuperação declarativa;
- comandos de seleção de Pods evitam depender de `.items[0]` durante um RollingUpdate sempre que isso possa selecionar uma revisão antiga;
- micropráticas M6 passaram a exigir confirmação da pasta de trabalho e da variável `$NS` antes dos comandos relativos;
- Helm passou a usar `helm lint`, `--wait` e `--timeout 120s`, seguido de validação de Deployment, Service, Pod e EndpointSlice;
- Kustomize passou a distinguir explicitamente **nome do recurso** de **label**: `nameSuffix: -dev` altera `metadata.name`, mas a label `app=symfony-demo-kustomize` mantém-se neste cenário;
- o selector correto para localizar o Pod Kustomize DEV é `-l app=symfony-demo-kustomize`, e não `-l app=symfony-demo-kustomize-dev`;
- os cleanups de Helm e Kustomize confirmam a remoção dos objetos temporários e a preservação da baseline `symfony-demo` em 2/2.

## Particularidades observadas no cluster de ensaio

### Metrics Server

O Metrics Server não estava inicialmente funcional porque os certificados de serving dos kubelets não continham os IPs nos SANs. No laboratório foi utilizado `--kubelet-insecure-tls` como **workaround exclusivo de ambiente de formação**. Em produção deve corrigir-se a cadeia/certificados dos kubelets, não normalizar este bypass.

### Relógio / Events

Foram observados Events com `AGE <invalid>`. O cluster também apresentava sincronização temporal incompleta. Antes da formação deve ser verificado e corrigido o serviço NTP efetivamente instalado, sem assumir `systemd-timesyncd` ou outro daemon específico.

### HPA durante rollouts

Durante a substituição de Pods surgiram avisos transitórios `FailedGetResourceMetric`/`FailedComputeMetricsReplicas` enquanto os novos Pods ainda não tinham métricas. No ensaio desapareceram com o workload estabilizado.

### NetworkPolicy — falha de comando não é prova de bloqueio

Durante a revisão final, os Pods de teste tinham terminado naturalmente e `kubectl exec` falhava porque os containers estavam em `Succeeded/Completed`. Esse erro não foi aceite como evidência da NetworkPolicy.

Após recriar os clientes, foi confirmado:

```text
client-allowed → 1/1 Running → access=symfony-demo → /health responde
client-blocked → 1/1 Running → access=blocked       → /health termina por timeout
```

Os scripts foram reforçados para validar estas precondições antes de produzir uma conclusão.

### `rollout undo` depois de `kubectl apply`

O cliente apresentou um warning de que o rollback não atualiza a annotation `kubectl.kubernetes.io/last-applied-configuration`. O laboratório mantém `rollout undo` porque é o objeto pedagógico do exercício; num fluxo declarativo/GitOps, a recuperação deve também repor a configuração desejada na fonte declarativa.

### Kustomize: `nameSuffix` e labels

No overlay DEV, o nome do Deployment muda para:

```text
symfony-demo-kustomize-dev
```

mas o Pod mantém:

```text
app=symfony-demo-kustomize
```

O Deployment e o Service usam o mesmo valor no selector, pelo que o backend é corretamente descoberto. Esta distinção foi confirmada em runtime e passou a estar explícita no guião.

### Helm: `deployed` não é prova isolada de serviço funcional

A revalidação M6 confirmou `STATUS: deployed`, mas a validação só foi considerada completa depois de observar:

```text
Deployment 1/1
Pod 1/1 Running
Service porta 80
selector coerente
EndpointSlice ready=true / serving=true
```

Isto evita ensinar que o estado da release, isoladamente, prova a operacionalidade da aplicação.

## O que continua fora desta revalidação runtime

- acesso externo via Ingress após aplicação da NetworkPolicy.

Este ponto continua dependente da configuração real do Ingress Controller e das regras necessárias para permitir esse tráfego.

## Validação estática da versão final

Após a consolidação inicial foi executada uma bateria estática sobre o pacote:

- parsing de todos os YAML que não contêm templates Helm;
- `bash -n` sobre todos os scripts shell;
- verificação de nomes `postgres`, `postgres-credentials`, `symfony` e labels `app=symfony-demo`;
- verificação dos resources/probes validados;
- HPA `2..5` com target CPU `50%`;
- SecurityContext e ServiceAccount;
- seletores da NetworkPolicy;
- patch da release candidata;
- pesquisa de referências obsoletas do pacote anterior.

**Resultado da bateria estática inicial: 37 verificações OK, 0 erros.**

Os templates Helm que não tinham sido renderizados nesse ambiente foram posteriormente renderizados e instalados no cluster de formação durante a revalidação M6. As micropráticas Kustomize também foram renderizadas, aplicadas e removidas em runtime.
