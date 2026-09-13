# Folha de Evidências — Sessão 6
## Kubernetes Admin III — Recursos, Scheduling e Segurança

**Formando:** ______________________________  
**Data:** ______________________________  
**Cluster/contexto:** ______________________________

Esta folha acompanha o laboratório integrado e centraliza as evidências de governação. O objetivo é registar prova suficiente para explicar o comportamento observado, incluindo caminhos permitidos e negados.

## Baseline e continuidade

| Evidência | Resultado observado | Estado |
|---|---|:---:|
| `k8s-cp-01` Ready / `192.168.50.46` | | ☐ |
| `k8s-wk-01` Ready / `192.168.50.65` | | ☐ |
| `k8s-wk-03` Ready / `192.168.50.102` | | ☐ |
| Kubernetes `1.36.4` | | ☐ |
| containerd `2.2.6` | | ☐ |
| Calico `3.32.2` operacional | | ☐ |
| CoreDNS operacional | | ☐ |

> `k8s-wk-03` já faz parte da baseline da Sessão 5. Foi preparado pelo formador antes dessa sessão, fora do tempo de aula, reutilizando o procedimento de join praticado na Sessão 4.

## Checkpoints

| CP | Evidência mínima | Resultado / observação | Validado |
|---:|---|---|:---:|
| CP1 | preflight + smoke-test CNI nos dois Workers | | ☐ |
| CP2 | requests/limits + `FailedScheduling` com `NODE=<none>` | | ☐ |
| CP3 | defaults de LimitRange + rejeição de ResourceQuota | | ☐ |
| CP4 | nodeSelector/Affinity + `IgnoredDuringExecution` | | ☐ |
| CP5 | duas réplicas distribuídas + terceira não agendável | | ☐ |
| CP6 | taint bloqueia; toleration + selector permite | | ☐ |
| CP7 | `get pods=yes`, `delete pods=no`, `get secrets=no` | | ☐ |
| CP8 | UID/GID 10001, seccomp, sem escalation, rootfs read-only, sem token | | ☐ |
| CP9 | Secret criado sem expor valores + acesso negado por RBAC | | ☐ |
| CP10 | DNS/app/db permitidos apenas nos fluxos previstos | | ☐ |
| CP11 | fotografia final de quota, placement, RBAC, security e policies | | ☐ |
| CP12 | namespace removido, label/taint limpos, contexto `default` | | ☐ |

## Testes negativos obrigatórios

| Teste | Evidência de falha esperada | Resultado |
|---|---|---|
| request impossível | Pod existe, `NODE=<none>`, `FailedScheduling` | |
| quota excedida | API rejeita / objeto não existe | |
| selector impossível | `FailedScheduling` | |
| Anti-Affinity com 3 réplicas | terceira réplica sem Node | |
| Pod sem toleration | `Pending`, sem Node | |
| RBAC delete Pods | `no` | |
| RBAC get Secrets | `no` | |
| escrita em root filesystem | `Read-only file system` | |
| default-deny NetworkPolicy | DNS/HTTP/DB bloqueados | |
| cliente → PostgreSQL no estado final | bloqueado | |

## Matriz final de NetworkPolicy

| Fluxo | Resultado esperado | Resultado observado |
|---|---|---|
| DNS → CoreDNS | PERMITIDO | |
| `net-client → net-app:80` | PERMITIDO | |
| `net-app → net-db:5432` | PERMITIDO | |
| `net-client → net-db:5432` | BLOQUEADO | |

## Regra de evidência final

O laboratório fica concluído quando o formando consegue explicar, com evidência:

```text
recursos declarados e quota aplicada
+
admission ≠ scheduling
+
placement controlado
+
anti-affinity positiva e negativa
+
taints/tolerations
+
identidade + autorização mínima
+
SecurityContext verificado pelo comportamento
+
Secret protegido por controlo de acesso
+
NetworkPolicy com caminho permitido e caminho bloqueado
+
cleanup completo
```

**Conclusão do formando:**  
______________________________________________________________________  
______________________________________________________________________
