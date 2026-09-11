# Recursos do formador — Sessão 5

## Validador técnico

O ficheiro [`validar_lab_sessao5.sh`](validar_lab_sessao5.sh) foi criado para validar a baseline **antes** da formação.

Executar no `k8s-cp-01`:

```bash
chmod +x validar_lab_sessao5.sh
./validar_lab_sessao5.sh
```

O script:

- não substitui o laboratório do formando;
- cria um namespace temporário;
- valida Nodes, CoreDNS, local-path, Traefik e Gateway API;
- testa DaemonSet, StatefulSet, DNS, PVC/PV, Symfony, Ingress, Gateway API, PostgreSQL, backup e restore;
- gera um relatório TXT;
- elimina o namespace temporário no final, salvo configuração de diagnóstico.

Baseline validada:

```text
Kubernetes 1.36.4
k8s-cp-01
k8s-wk-01
k8s-wk-03
```

A execução de validação de 11/09/2026 terminou com:

```text
48 OK
0 avisos
0 falhas
RESULTADO GLOBAL: APROVADO
```
