# Lab 2 — Logs, Exec, Inspect e Stats

**Duração prevista:** 25 minutos  
**Objetivo:** recolher evidências sobre estado, configuração e consumo de um container.

## Preparação

```bash
docker run -d \
  --name web-demo \
  -p 8080:80 \
  nginx:alpine
```

## 1. Logs

```bash
docker logs web-demo
curl http://localhost:8080
curl http://localhost:8080/nao-existe
docker logs web-demo
```

Siga os logs em tempo real:

```bash
docker logs -f web-demo
```

Noutro terminal, gere novos pedidos e termine o seguimento com `Ctrl+C`.

## 2. Execução dentro do container

```bash
docker exec -it web-demo /bin/sh
```

Dentro do container:

```sh
hostname
cat /etc/os-release
ls -la /usr/share/nginx/html
exit
```

> `docker exec` é útil para diagnóstico. Não deve ser encarado como mecanismo normal para alterar manualmente uma aplicação em produção.

## 3. Inspect

```bash
docker inspect web-demo
```

Localize imagem, estado, IP, rede, portas, mounts e variáveis de ambiente.

Experimente:

```bash
docker inspect --format '{{.State.Status}}' web-demo
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-demo
docker port web-demo
```

## 4. Stats

```bash
docker stats --no-stream web-demo
```

Identifique CPU, memória, rede e I/O.

## Método

```text
Existe?
   ↓
Está em execução?
   ↓
O que dizem os logs?
   ↓
Como está configurado?
   ↓
Que recursos utiliza?
```

### Exercício final

Descubra estado atual, IP, porta publicada, utilização de memória e últimas linhas de log.
