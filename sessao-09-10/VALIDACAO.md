# Validação técnica — Sessões 9 e 10

## Resultado global

**Pacote consolidado após validação runtime real do laboratório principal.**

Data do ensaio de referência: **16/09/2026**.

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
| NetworkPolicy | ✅ | cliente autorizado passou; cliente bloqueado terminou em timeout |
| Release candidata | ✅ | `1.2.0-rc1` + readiness inválida criou nova revisão não Ready |
| Disponibilidade durante falha | ✅ | versão estável continuou a responder pelo Service |
| Rollback | ✅ | `rollout undo` restaurou `1.1.0`, `/ready` e Deployment 2/2 |

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
- release candidata altera imagem + readiness numa única revisão;
- rollback inclui nota sobre `kubectl apply`/`last-applied-configuration` e recuperação declarativa;
- comandos de seleção de Pods evitam depender de `.items[0]` durante um RollingUpdate sempre que isso possa selecionar uma revisão antiga.

## Particularidades observadas no cluster de ensaio

### Metrics Server

O Metrics Server não estava inicialmente funcional porque os certificados de serving dos kubelets não continham os IPs nos SANs. No laboratório foi utilizado `--kubelet-insecure-tls` como **workaround exclusivo de ambiente de formação**. Em produção deve corrigir-se a cadeia/certificados dos kubelets, não normalizar este bypass.

### Relógio / Events

Foram observados Events com `AGE <invalid>`. O cluster também apresentava sincronização temporal incompleta. Antes da formação deve ser verificado e corrigido o serviço NTP efetivamente instalado, sem assumir `systemd-timesyncd` ou outro daemon específico.

### HPA durante rollouts

Durante a substituição de Pods surgiram avisos transitórios `FailedGetResourceMetric`/`FailedComputeMetricsReplicas` enquanto os novos Pods ainda não tinham métricas. No ensaio desapareceram com o workload estabilizado.

### `rollout undo` depois de `kubectl apply`

O cliente apresentou um warning de que o rollback não atualiza a annotation `kubectl.kubernetes.io/last-applied-configuration`. O laboratório mantém `rollout undo` porque é o objeto pedagógico do exercício; num fluxo declarativo/GitOps, a recuperação deve também repor a configuração desejada na fonte declarativa.

## O que não foi revalidado em runtime neste ensaio final

- renderização/aplicação dos exercícios Kustomize;
- renderização/instalação do chart Helm;
- acesso externo via Ingress após aplicação da NetworkPolicy.

Estes componentes continuam no pacote por fazerem parte de M6/M4, mas devem ser ensaiados no cluster antes da aula se forem utilizados.

## Validação estática da versão final

Após a consolidação foi executada uma nova bateria estática sobre o pacote final:

- parsing de todos os YAML que não contêm templates Helm;
- `bash -n` sobre todos os scripts shell;
- verificação de nomes `postgres`, `postgres-credentials`, `symfony` e labels `app=symfony-demo`;
- verificação dos resources/probes validados;
- HPA `2..5` com target CPU `50%`;
- SecurityContext e ServiceAccount;
- seletores da NetworkPolicy;
- patch da release candidata;
- pesquisa de referências obsoletas do pacote anterior.

**Resultado: 37 verificações OK, 0 erros.**

Os templates Helm não foram renderizados neste ambiente porque o binário `helm` não está disponível; por isso continuam assinalados como ponto a ensaiar no cluster da formação.
