# Folha de Evidências — Sessão 5
## Kubernetes Admin II — Workloads, Networking, Storage, Backup e Recuperação

**Formando:** ______________________________  
**Data:** ______________________________  
**Cluster/contexto:** ______________________________

Esta folha acompanha o laboratório integrado. O objetivo não é copiar outputs completos, mas registar a evidência mínima que permite explicar o resultado de cada checkpoint.

## Baseline e continuidade

| Evidência | Resultado observado | Estado |
|---|---|:---:|
| `k8s-cp-01` Ready / `192.168.50.46` | | ☐ |
| `k8s-wk-01` Ready / `192.168.50.65` | | ☐ |
| `k8s-wk-03` Ready / `192.168.50.102` | | ☐ |
| Kubernetes `1.36.4` | | ☐ |
| containerd `2.2.6` | | ☐ |
| Calico operacional | | ☐ |
| StorageClass `local-path` | | ☐ |
| Traefik / GatewayClass operacionais | | ☐ |

> `k8s-wk-03` é infraestrutura preparada pelo formador antes da Sessão 5, fora dos 240 minutos, reutilizando o procedimento de join já demonstrado na Sessão 4.

## Checkpoints

| CP | Evidência mínima | Resultado / observação | Validado |
|---:|---|---|:---:|
| CP1 | Nodes Ready + storage + Traefik/Gateway API | | ☐ |
| CP2 | Deployment reconcilia e Pod substituto tem nova identidade | | ☐ |
| CP3 | DaemonSet cria Pod em cada Worker elegível | | ☐ |
| CP4 | StatefulSet apresenta ordinais estáveis | | ☐ |
| CP5 | Headless DNS resolve nomes individuais dos Pods | | ☐ |
| CP6 | `web-1` reaparece com UID diferente | | ☐ |
| CP7 | PVC `Pending → Bound`; PV e `nodeAffinity` identificados | | ☐ |
| CP8 | dados sobrevivem à recriação do Pod sem falso positivo | | ☐ |
| CP9 | Symfony usa PVC e marcador SQLite foi criado | | ☐ |
| CP10 | selector incorreto identificado por EndpointSlice e corrigido | | ☐ |
| CP11 | Ingress devolve HTTP 200 | | ☐ |
| CP12 | Gateway/HTTPRoute `Accepted=True` e `ResolvedRefs=True` | | ☐ |
| CP13 | backup online com `INTEGRITY_CHECK=ok` e hash | | ☐ |
| CP14 | execução manual do CronJob validada | | ☐ |
| CP15 | backup copiado para fora do PVC/storage Kubernetes da aplicação | | ☐ |
| CP16 | perda do Pod recuperada pela persistência | | ☐ |
| CP17 | eliminação lógica da PVC/PV antigo demonstrada | | ☐ |
| CP18 | nova PVC/PV + restore + integridade + HTTP 200 | | ☐ |
| CP19 | síntese, autoavaliação e limpeza | | ☐ |

## Health gate obrigatório antes do CP17

Não iniciar a eliminação controlada da PVC enquanto os pontos seguintes não estiverem validados:

- [ ] `deployment/symfony-demo` está saudável antes de ser escalado para zero.
- [ ] `symfony-data` e `backup-pvc` estão `Bound`.
- [ ] `sqlite-online-backup` terminou com `Complete`.
- [ ] `MARKER_BACKUP=persistencia-sessao5-ok`.
- [ ] `INTEGRITY_CHECK=ok`.
- [ ] `database-online.sqlite` foi copiado para fora do PVC/storage Kubernetes da aplicação e `test -s` teve sucesso.
- [ ] o endpoint `/health` devolveu HTTP 200 antes da operação destrutiva.

> Se o comando `kubectl cp` for executado no próprio `k8s-cp-01`, a cópia fica fora do PVC da aplicação, mas **não** fora da infraestrutura física do cluster. Para proteção contra perda total do cluster/hosts, a cópia deve ainda ser transferida para um sistema externo independente.

Se algum destes pontos falhar, parar e diagnosticar antes de apagar a PVC.

## Classificação de falhas

| Sintoma | Camada provável | Evidência usada |
|---|---|---|
| Pod sem Node + `FailedScheduling` | Scheduling | |
| PVC Pending sem consumidor com `WaitForFirstConsumer` | Estado esperado | |
| PVC Pending depois de existir consumidor | Provisioning/storage | |
| Pod com Node + `FailedMount` | Mount/storage | |
| Service sem EndpointSlice | Selector/labels | |
| Route não aceite/resolvida | Gateway API | |

## Regra de evidência final

O laboratório fica concluído quando o formando consegue explicar, com evidência:

```text
workload correto
+
reconciliação
+
identidade estável
+
DNS / Service / entrada HTTP
+
dynamic provisioning
+
persistência
+
backup consistente
+
backup fora do storage primário da aplicação
+
falha controlada
+
restore validado
+
PERSISTÊNCIA ≠ BACKUP ≠ ALTA DISPONIBILIDADE
```

**Conclusão do formando:**  
______________________________________________________________________  
______________________________________________________________________
