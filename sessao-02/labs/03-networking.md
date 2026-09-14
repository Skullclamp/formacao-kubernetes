# Lab 3 — Networking Docker

**Sessão:** 2  
**Duração prevista:** 30 minutos  
**Nível:** intermédio  
**Objetivo:** criar redes Docker, validar resolução de nomes entre containers e demonstrar isolamento entre redes.

A questão orientadora é:

> Como podem dois containers comunicar sem depender de IPs que podem mudar?

---

# CP1 — Inventariar as redes existentes

## Objetivo

Reconhecer as redes criadas por omissão pelo Docker antes de acrescentar redes próprias.

```bash
docker network ls
```

### O que estamos a fazer e porquê

Antes de criar recursos, observamos o estado atual. Isto permite distinguir redes preexistentes das redes criadas pelo laboratório.

### O que observar

Identifique pelo menos:

- `bridge` — rede bridge predefinida do Docker;
- `host` — modo que usa diretamente a stack de rede do host, quando suportado;
- `none` — container sem conectividade de rede normal.

A sessão concentra-se em **redes bridge definidas pelo utilizador**, porque disponibilizam isolamento e resolução de nomes adequada ao cenário multi-container.

### CHECKPOINT CP1

```text
redes predefinidas identificadas
nenhuma rede do laboratório criada ainda
```

**Evidência:** guardar `docker network ls`.

---

# CP2 — Criar e inspecionar uma rede própria

## Objetivo

Criar uma rede bridge explícita para a aplicação.

```bash
docker network create app-network
docker network inspect app-network
```

### Explicação dos comandos

- `docker network create NOME` cria uma rede definida pelo utilizador; se não indicarmos outro driver, é usada uma bridge local;
- `docker network inspect NOME` devolve a configuração detalhada da rede em JSON, incluindo driver, subnet e containers ligados.

### Porque criamos uma rede explícita?

Ao colocar os containers relacionados na mesma rede, podemos usar **nomes** em vez de codificar IPs. Isto reduz o acoplamento a endereços efémeros.

### O que observar

Em `docker network inspect app-network`, localize:

```text
Driver
IPAM.Config/Subnet
Containers
```

Nesta fase a secção `Containers` pode estar vazia.

### CHECKPOINT CP2

```text
app-network existe
driver e subnet identificados
```

---

# CP3 — Ligar um serviço Web à rede

## Objetivo

Criar um container acessível por outros containers da mesma rede, sem publicar a sua porta no host.

```bash
docker run -d \
  --name web-net \
  --network app-network \
  nginx:alpine
```

### Flags

- `-d` executa o serviço em background;
- `--name web-net` atribui o nome que será também utilizável na resolução interna da rede;
- `--network app-network` liga o container à rede criada no CP2;
- não usamos `-p` porque este teste pretende demonstrar **comunicação interna entre containers**, não acesso pelo host.

Confirmar:

```bash
docker ps --filter 'name=web-net'
docker network inspect app-network
```

### O que observar

A rede deverá agora listar `web-net` entre os containers ligados e atribuir-lhe um endereço IP interno.

---

# CP4 — Provar resolução por nome dentro da rede

## Objetivo

Demonstrar que um segundo container consegue localizar `web-net` pelo nome na rede definida pelo utilizador.

```bash
docker run --rm \
  --network app-network \
  busybox:stable \
  wget -qO- http://web-net
```

### Flags e argumentos

| Elemento | Significado |
|---|---|
| `--rm` | remove automaticamente o container cliente quando o comando termina |
| `--network app-network` | coloca o cliente na mesma rede do Nginx |
| `busybox:stable` | imagem leve usada apenas como cliente de diagnóstico |
| `wget` | realiza o pedido HTTP |
| `-q` | reduz mensagens do `wget` |
| `-O-` | envia o corpo recebido para stdout (`-`) em vez de o gravar num ficheiro |
| `http://web-net` | usa o nome do container, não um IP codificado |

### O que observar

O HTML do Nginx deve surgir no terminal. O cliente não precisou de conhecer o IP de `web-net`.

### CHECKPOINT CP4

```text
cliente e servidor na mesma rede
nome web-net resolvido internamente
HTTP funcional sem publicação de porta no host
```

**Evidência:** guardar a resposta ou uma parte identificável do HTML.

---

# CP5 — Teste negativo: isolamento entre redes

## Objetivo

Provar que a resolução/comunicação anterior depende de os containers partilharem uma rede adequada.

Criar uma segunda rede:

```bash
docker network create outra-network
```

Executar o mesmo cliente, agora isolado em `outra-network`:

```bash
docker run --rm \
  --network outra-network \
  busybox:stable \
  wget -T 3 -qO- http://web-net
```

### Flags adicionais

- `-T 3` limita o tempo de espera do `wget`, evitando ficar indefinidamente à espera durante o teste negativo.

### Resultado esperado

O pedido deve falhar porque o cliente não partilha nenhuma rede com `web-net`. A falha controlada demonstra isolamento; não deve ser “corrigida” publicando uma porta.

Confirmar a separação:

```bash
docker network inspect app-network
docker network inspect outra-network
```

### CHECKPOINT CP5

O formando consegue explicar:

```text
mesma rede → nome e comunicação disponíveis
redes sem interseção → web-net não está alcançável por esse cliente
```

**Evidência:** guardar a falha do pedido e a associação dos containers às redes.

---

# CP6 — Ligar o mesmo container a uma segunda rede

## Objetivo

Mostrar que um container pode participar em mais do que uma rede Docker.

```bash
docker network connect outra-network web-net
```

### Explicação

`docker network connect REDE CONTAINER` acrescenta uma interface/ligação de rede a um container já existente. Não substitui a ligação anterior a `app-network`.

Repetir o cliente:

```bash
docker run --rm \
  --network outra-network \
  busybox:stable \
  wget -T 3 -qO- http://web-net
```

Inspecionar:

```bash
docker inspect \
  --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} -> {{$cfg.IPAddress}}{{"\n"}}{{end}}' \
  web-net
```

### O que observar

`web-net` deverá possuir uma ligação a `app-network` e outra a `outra-network`, normalmente com IPs diferentes.

### CHECKPOINT CP6

```text
web-net ligado a duas redes
cliente de outra-network passa a comunicar
não foi necessário publicar qualquer porta no host
```

---

# CP7 — Limpeza e ponte conceptual para Kubernetes

Remover o container antes das redes, porque uma rede em utilização não pode ser removida normalmente:

```bash
docker rm -f web-net
docker network rm app-network outra-network
```

- `docker rm -f` pára e remove o container;
- `docker network rm` remove redes que já não têm endpoints ativos.

Confirmar:

```bash
docker network ls
```

### Relação a reter

```text
Docker
container/serviço numa rede definida pelo utilizador
        ↓
resolução interna por nome

Kubernetes
Service
        ↓
DNS interno do cluster
```

Os mecanismos não são iguais, mas partilham uma ideia importante: **as aplicações não devem depender diretamente de IPs efémeros quando existe uma abstração de descoberta adequada**.

### Regra de evidência deste laboratório

O laboratório fica concluído quando o formando consegue provar e explicar:

```text
app-network criada
+
web-net ligado à rede
+
resolução por nome funcional na mesma rede
+
teste negativo entre redes isoladas
+
comunicação restaurada após network connect
+
recursos do laboratório removidos
```
