# Symfony Demo — variante pedagógica

Esta diretoria será o ponto de referência para a aplicação transversal da formação.

## Base da aplicação

A variante pedagógica parte da **Symfony Demo Application `v3.1.0`**, utilizando:

- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16 no laboratório containerizado.

## Extensões pedagógicas

A variante utilizada na formação inclui os endpoints:

```text
/info
/health
/ready
```

Objetivo conceptual:

| Endpoint | Função no laboratório |
|---|---|
| `/info` | identificar aplicação, versão, ambiente e instância |
| `/health` | confirmar que o processo/aplicação responde |
| `/ready` | confirmar que a aplicação está pronta para servir operações dependentes da BD |

## Disponibilização do código

Na **Sessão 2** os formandos consomem uma imagem previamente construída. O código e os ficheiros de build serão disponibilizados quando forem necessários para a **Sessão 3 — Docker II: Da Aplicação à Produção**.

> Docker `HEALTHCHECK` e probes Kubernetes são conceitos relacionados, mas Kubernetes não utiliza automaticamente o `HEALTHCHECK` definido na imagem Docker como probe.
