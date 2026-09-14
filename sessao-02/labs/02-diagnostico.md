# Lab 2 — Logs, Exec, Inspect e Stats

**Sessão:** 2  
**Duração prevista:** 25 minutos  
**Nível:** intermédio  
**Objetivo:** recolher e interpretar evidências sobre estado, configuração e consumo de recursos de um container antes de alterar o ambiente.

Neste laboratório aplicamos uma regra operacional que será reutilizada em Kubernetes:

```text
OBSERVAR
   ↓
RECOLHER EVIDÊNCIA
   ↓
FORMULAR HIPÓTESE
   ↓
SÓ DEPOIS ALTERAR
```

---

# CP1 — Preparar e validar o container de diagnóstico

## Objetivo

Criar um serviço conhecido e confirmar que está funcional antes de começarmos a diagnosticá-lo.

## O que estamos a fazer e porquê

Sem um estado inicial conhecido, não conseguimos distinguir uma anomalia introduzida durante o exercício de uma falha que já existia.

```bash
docker run -d \
  --name web-demo \
  -p 8080:80 \
  nginx:alpine
```

### Flags

- `-d` executa o container em background;
- `--name web-demo` atribui um nome previsível;
- `-p 8080:80` publica `HOST:CONTAINER`, ou seja, porta `8080` do host para porta `80` do Nginx.

Validar:

```bash
docker ps --filter 'name=web-demo'
curl -i http://localhost:8080/
```

- `--filter 'name=web-demo'` limita a listagem ao container pretendido;
- `curl -i` inclui os cabeçalhos HTTP, permitindo confirmar também o código de resposta.

### CHECKPOINT CP1

```text
web-demo está Up
porta 8080 está publicada
HTTP devolve 200
```

**Evidência:** guardar o estado do container e o código HTTP.

---

# CP2 — Ler logs e relacioná-los com pedidos reais

## Objetivo

Perceber que os logs são evidência produzida pelo processo da aplicação e devem ser relacionados com ações observáveis.

## O que estamos a fazer e porquê

Primeiro observamos os logs existentes. Depois geramos deliberadamente um pedido válido e um pedido para um caminho inexistente, para relacionar causa e registo.

```bash
docker logs web-demo
curl -i http://localhost:8080/
curl -i http://localhost:8080/nao-existe
docker logs web-demo
```

### Explicação

- `docker logs CONTAINER` apresenta stdout/stderr do processo principal do container;
- o pedido `/` deverá produzir uma resposta bem-sucedida;
- `/nao-existe` deverá produzir uma resposta HTTP diferente, normalmente `404`, que também deve ficar visível nos logs.

Acompanhar em tempo real:

```bash
docker logs -f web-demo
```

- `-f` significa *follow*: mantém o comando ligado ao fluxo de novos logs.

Noutro terminal:

```bash
curl -s -o /dev/null -w 'HTTP=%{http_code}\n' http://localhost:8080/
```

- `-s` reduz output informativo do `curl`;
- `-o /dev/null` descarta o corpo da resposta;
- `-w` imprime apenas o formato indicado, aqui o código HTTP.

Termine o `docker logs -f` com `Ctrl+C`. Isto termina apenas o acompanhamento dos logs; **não termina o container**.

### CHECKPOINT CP2

```text
pedido HTTP gerado
entrada correspondente observada nos logs
Ctrl+C não parou o container
```

**Evidência:** mostrar uma linha de log correspondente a um dos pedidos realizados.

---

# CP3 — Executar um comando dentro de um container em execução

## Objetivo

Utilizar `docker exec` como ferramenta de inspeção pontual, sem transformar alterações manuais dentro do container num método de configuração.

```bash
docker exec -it web-demo /bin/sh
```

### Flags e argumentos

| Elemento | Função |
|---|---|
| `docker exec` | executa um novo processo dentro de um container já em execução |
| `-i` | mantém stdin aberto |
| `-t` | cria um pseudo-terminal para interação |
| `web-demo` | container alvo |
| `/bin/sh` | processo que será iniciado dentro do container |

Dentro do container:

```sh
hostname
cat /etc/os-release
ls -la /usr/share/nginx/html
exit
```

### O que observar

- `hostname` é a identidade observada dentro do container;
- `/etc/os-release` descreve o userland da imagem, não o kernel independente de uma VM;
- `/usr/share/nginx/html` é o conteúdo servido pelo Nginx nesta imagem;
- `exit` termina apenas a shell criada por `docker exec`.

> `docker exec` é uma ferramenta de diagnóstico. Alterar manualmente um container em produção cria configuração não reproduzível e desaparece quando o container é substituído.

### CHECKPOINT CP3

```text
shell executada dentro do container
informação recolhida
container continua Up depois de exit
```

---

# CP4 — Inspecionar a configuração declarada pelo Docker

## Objetivo

Consultar configuração e estado sem entrar no container.

```bash
docker inspect web-demo
```

`docker inspect` devolve a representação detalhada do objeto em JSON. Procure:

```text
Config.Image
State.Status
NetworkSettings
HostConfig.PortBindings
Mounts
Config.Env
```

Extrair apenas informação específica:

```bash
docker inspect \
  --format '{{.State.Status}}' \
  web-demo

docker inspect \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  web-demo

docker port web-demo
```

### Flags e sintaxe

- `--format` usa um template Go para selecionar campos do JSON em vez de imprimir toda a estrutura;
- `.State.Status` devolve o estado do container;
- `range .NetworkSettings.Networks` percorre as redes às quais o container está ligado;
- `.IPAddress` devolve o IP nessa rede;
- `docker port` apresenta as portas publicadas no host.

### O que observar

O IP interno do container **não é** a mesma coisa que `localhost:8080`. O primeiro pertence à rede Docker; o segundo é a publicação efetuada no host.

### CHECKPOINT CP4

O formando consegue localizar e explicar:

```text
imagem
estado
IP interno
rede
porta publicada
mounts
variáveis de ambiente
```

**Evidência:** guardar estado, IP interno e publicação de porta.

---

# CP5 — Observar consumo de recursos

## Objetivo

Obter uma fotografia do consumo de CPU, memória, rede e I/O do container.

```bash
docker stats --no-stream web-demo
```

### Flags

- `docker stats` apresenta métricas de utilização dos containers;
- sem opções, o output é atualizado continuamente;
- `--no-stream` obtém uma única amostra e termina.

### O que observar

Identifique pelo menos:

```text
CPU %
MEM USAGE / LIMIT
NET I/O
BLOCK I/O
PIDS
```

Uma amostra pontual não constitui monitorização histórica. Serve aqui para aprender **onde observar** o consumo antes de tirar conclusões.

---

# CP6 — Diagnóstico final por evidência

Sem executar comandos destrutivos, descubra:

1. estado atual;
2. imagem utilizada;
3. IP interno;
4. porta publicada;
5. utilização de memória;
6. últimas linhas de log.

Pode usar:

```bash
docker ps --filter 'name=web-demo'
docker inspect --format '{{.Config.Image}} {{.State.Status}}' web-demo
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web-demo
docker port web-demo
docker stats --no-stream web-demo
docker logs --tail 10 web-demo
```

- `--tail 10` limita os logs às dez linhas mais recentes.

### Regra de evidência deste laboratório

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
   ↓
Só depois decidir o que alterar
```

### CHECKPOINT CP6 — conclusão

O laboratório fica concluído quando o formando consegue apresentar os seis elementos pedidos e explicar **que comando forneceu cada evidência**.

Limpeza:

```bash
docker rm -f web-demo
```

`-f` permite parar e remover o container numa única operação de limpeza. Em troubleshooting real, não deve ser o primeiro comando perante uma falha, porque elimina estado potencialmente útil para diagnóstico.
