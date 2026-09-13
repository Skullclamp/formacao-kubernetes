# Manifests — Sessão 6

Diretoria reservada aos manifests utilizados no laboratório de **Recursos, Scheduling e Segurança**.

## Organização prevista

Os manifests serão adicionados de forma incremental e numerada, cobrindo:

- Namespace de laboratório;
- requests e limits;
- ResourceQuota;
- LimitRange;
- nodeSelector;
- Node Affinity;
- Pod Anti-Affinity;
- taints/tolerations — lado do workload;
- ServiceAccount;
- Role / RoleBinding;
- ClusterRole / ClusterRoleBinding, apenas quando pedagogicamente necessário;
- SecurityContext;
- Secret de laboratório sem dados reais;
- NetworkPolicy para cenários permitidos e bloqueados;
- Pods/Deployments de diagnóstico e validação.

## Regra

Cada manifest deverá corresponder a um checkpoint explícito do laboratório e incluir apenas a configuração necessária para demonstrar o conceito em causa.
