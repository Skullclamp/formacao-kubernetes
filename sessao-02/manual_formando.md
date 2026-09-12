# Manual do Formando — Docker — Operação, Networking, Storage e Compose

---

# Índice

1. [Imagens e obtenção a partir de registries](#1-imagens-e-obtenção-a-partir-de-registries)
2. [Ciclo de vida dos containers](#2-ciclo-de-vida-dos-containers)
3. [`docker run` em detalhe](#3-docker-run-em-detalhe)
4. [Publicação de portas](#4-publicação-de-portas)
5. [Logs e observação](#5-logs-e-observação)
6. [`docker exec`](#6-docker-exec)
7. [`docker inspect`](#7-docker-inspect)
8. [`docker stats` e recursos](#8-docker-stats-e-recursos)
9. [Networking Docker](#9-networking-docker)
10. [Bridge networks](#10-bridge-networks)
11. [DNS e comunicação entre containers](#11-dns-e-comunicação-entre-containers)
12. [Filesystem do container](#12-filesystem-do-container)
13. [Bind mounts](#13-bind-mounts)
14. [Named volumes](#14-named-volumes)
15. [Persistência não é backup](#15-persistência-não-é-backup)
16. [Docker Compose](#16-docker-compose)
17. [Services em Compose](#17-services-em-compose)
18. [Networks em Compose](#18-networks-em-compose)
19. [Volumes em Compose](#19-volumes-em-compose)
20. [Variáveis e configuração](#20-variáveis-e-configuração)
21. [Dependências e healthchecks](#21-dependências-e-healthchecks)
22. [Ciclo de vida com Compose](#22-ciclo-de-vida-com-compose)
23. [Caso prático — Symfony Demo e PostgreSQL](#23-caso-prático--symfony-demo-e-postgresql)
24. [Troubleshooting operacional](#24-troubleshooting-operacional)
25. [Síntese](#25-síntese)
26. [Guia rápido Docker](#26-guia-rápido-docker)
27. [Guia rápido Docker Compose](#27-guia-rápido-docker-compose)
28. [Glossário](#28-glossário)
29. [Recursos e leituras complementares](#29-recursos-e-leituras-complementares)

---

# 1. Imagens e obtenção a partir de registries

Um container em execução nasce normalmente a partir de uma **imagem**. A imagem contém o filesystem, executáveis, bibliotecas, metadata e configuração necessários para iniciar o processo do container.

Convém manter sempre a distinção:

```text
Imagem
  │
  │ modelo imutável / artefacto
  ▼
Container
  │
  │ instância em execução
  ▼
Processo
```

Uma imagem não é um container parado. São objetos diferentes.

Pode existir:

```text
1 imagem nginx
      │
      ├── container web-1
      ├── container web-2
      └── container web-3
```

Os três containers podem ter estados, redes, mounts e writable layers diferentes, apesar de terem sido criados a partir da mesma imagem.

## 1.1. Registry, repository e imagem

Um **registry** é um serviço que armazena e distribui imagens.

Exemplos conhecidos incluem:

- Docker Hub;
- GitHub Container Registry;
- GitLab Container Registry;
- Harbor;
- registries disponibilizados por fornecedores cloud.

Dentro de um registry existem **repositories**.

Uma referência pode ter uma forma semelhante a:

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
```

Podemos decompô-la:

```text
ghcr.io
└── registry

skullclamp/symfony-demo
└── repository

1.0.0
└── tag
```

A tag é uma referência legível. Por si só, uma tag não deve ser interpretada como uma garantia criptográfica de identidade do conteúdo.

Na operação diária é preferível utilizar versões explícitas sempre que a previsibilidade é importante:

```bash
docker pull postgres:16
```

em vez de depender indiscriminadamente de:

```bash
docker pull postgres:latest
```

`latest` é apenas uma tag convencional. Não significa que o runtime determine automaticamente qual é a versão “mais recente” em termos cronológicos ou funcionais.

## 1.2. Obter uma imagem

```bash
docker pull postgres:16
```

O fluxo conceptual é:

```text
Docker CLI
    │
    ▼
Docker Engine
    │
    ▼
Registry
    │
    ├── manifest
    ├── config
    └── layers
          │
          ▼
     armazenamento local
```

Listar imagens disponíveis localmente:

```bash
docker image ls
```

Forma abreviada ainda muito utilizada:

```bash
docker images
```

Ver uma imagem concreta:

```bash
docker image inspect postgres:16
```

## 1.3. O que acontece se `docker run` não encontrar a imagem localmente?

Por omissão, se a imagem referenciada não estiver disponível localmente, Docker tenta obtê-la a partir do registry correspondente.

Por isso:

```bash
docker run postgres:16
```

pode produzir inicialmente mensagens de `pull`.

Depois de a imagem estar local, execuções seguintes podem reutilizar as layers existentes.

> **Importante**  
> “A imagem existe localmente” e “o container está a correr” são estados independentes. Eliminar um container não elimina automaticamente a imagem que lhe deu origem.

---

# 2. Ciclo de vida dos containers

Um container não deve ser entendido apenas como “a aplicação”. Docker mantém metadata e estado relacionados com o objeto container.

Um modelo simplificado é:

```text
create
  │
  ▼
created
  │
  │ start
  ▼
running
  │
  ├── stop ───────► exited
  │                  │
  │                  │ start
  │                  └────────► running
  │
  └── processo termina
          │
          ▼
        exited
          │
          ▼
          rm
          │
          ▼
       removido
```

## 2.1. Criar e iniciar num único passo

O comando mais habitual é:

```bash
docker run ...
```

Conceptualmente, `run` combina várias operações:

```text
docker run
    │
    ├── localizar/pull da imagem
    ├── criar objeto container
    ├── preparar writable layer
    ├── configurar namespaces
    ├── configurar cgroups
    ├── preparar networking
    ├── montar volumes/mounts
    └── iniciar o processo principal
```

## 2.2. Listar containers em execução

```bash
docker ps
```

ou:

```bash
docker container ls
```

Apresenta normalmente:

- ID;
- imagem;
- comando;
- tempo desde criação;
- estado;
- portas;
- nome.

## 2.3. Incluir containers terminados

```bash
docker ps -a
```

Isto é essencial em troubleshooting.

Um container que “desapareceu” de:

```bash
docker ps
```

pode simplesmente estar em estado `Exited`.

## 2.4. Parar um container

```bash
docker stop web
```

Docker tenta realizar uma terminação graciosa do processo principal antes de recorrer a uma terminação forçada.

Isto é importante porque muitas aplicações precisam de:

- fechar ligações;
- terminar pedidos em processamento;
- descarregar buffers;
- sincronizar dados;
- libertar locks;
- fechar ficheiros.

## 2.5. Voltar a iniciar

```bash
docker start web
```

`start` inicia **o mesmo objeto container** anteriormente parado.

Isto é diferente de executar novamente:

```bash
docker run ...
```

que cria um novo container.

## 2.6. Reiniciar

```bash
docker restart web
```

É conceptualmente:

```text
running
   │
   ▼
 stop
   │
   ▼
 start
```

## 2.7. Remover

Um container parado pode ser removido com:

```bash
docker rm web
```

Forçar a remoção de um container em execução:

```bash
docker rm -f web
```

Esta última opção deve ser utilizada conscientemente. Forçar a remoção não é equivalente a permitir que a aplicação termine de forma normal.

## 2.8. `--rm`

Para containers temporários:

```bash
docker run --rm alpine echo "teste"
```

Quando o processo termina, Docker remove automaticamente o objeto container.

É útil em:

- testes;
- ferramentas CLI;
- tarefas curtas;
- inspeções pontuais.

Não é apropriado quando queremos manter o container parado para analisar:

- exit code;
- logs;
- filesystem gravável;
- metadata pós-execução.

## 2.9. O processo principal é decisivo

Um container permanece em execução enquanto o seu processo principal está em execução.

Exemplo:

```bash
docker run alpine echo "Olá"
```

O `echo` termina quase imediatamente.

Logo:

```text
container criado
      │
      ▼
echo executa
      │
      ▼
echo termina
      │
      ▼
container fica Exited
```

Isto explica muitos casos em que um formando espera que “o container fique ligado”, mas o processo principal não foi concebido para permanecer ativo.

---

# 3. `docker run` em detalhe

Considere:

```bash
docker run -d --name web -p 8080:80 nginx
```

Cada elemento tem significado próprio:

```text
docker run
└── criar e iniciar container

-d
└── detached mode

--name web
└── nome lógico do container

-p 8080:80
└── publicar host:container

nginx
└── referência da imagem
```

## 3.1. Detached vs. foreground

Sem `-d`, o terminal fica associado à execução.

Com:

```bash
docker run -d nginx
```

o container fica em background e o comando devolve o ID.

Para aplicações servidoras, o detached mode é comum.

## 3.2. Nome do container

```bash
docker run -d --name web nginx
```

O nome facilita:

```bash
docker logs web
docker inspect web
docker stop web
docker rm web
```

Sem `--name`, Docker atribui automaticamente um nome.

## 3.3. Variáveis de ambiente

```bash
docker run \
  -e APP_ENV=production \
  -e APP_VERSION=1.0.0 \
  minha-imagem
```

A variável é disponibilizada ao ambiente do processo dentro do container.

> **Segurança**  
> Variáveis de ambiente são úteis para configuração, mas valores sensíveis não devem ser espalhados por comandos, scripts, screenshots ou repositórios. Além disso, configuração por environment não transforma automaticamente o valor num segredo protegido.

## 3.4. Limites entre imagem e configuração de runtime

Uma imagem pode definir defaults, mas a operação do container acrescenta configuração de execução:

```text
Imagem
  │
  ├── filesystem base
  ├── comando default
  └── metadata
       │
       ▼
docker run
  │
  ├── nome
  ├── environment
  ├── mounts
  ├── network
  ├── portas
  └── outras opções
       │
       ▼
Container configurado
```

Dois containers da mesma imagem podem, portanto, comportar-se de forma diferente.

---

# 4. Publicação de portas

Um processo dentro de um container pode escutar numa porta sem que essa porta esteja publicada no host.

Considere um servidor web a escutar em:

```text
container: TCP/80
```

Isso não significa automaticamente:

```text
host: TCP/80
```

## 4.1. Publicar uma porta

```bash
docker run -d \
  --name web \
  -p 8080:80 \
  nginx
```

A relação é:

```text
Cliente
   │
   │ HOST:8080
   ▼
Docker host
   │
   │ port mapping
   ▼
Container
   │
   │ TCP/80
   ▼
nginx
```

A sintaxe base é:

```text
-p HOST_PORT:CONTAINER_PORT
```

## 4.2. Publicar numa interface específica

```bash
docker run -d \
  -p 127.0.0.1:8080:80 \
  nginx
```

Neste caso limitamos explicitamente o binding à interface loopback IPv4 do host.

Isto pode ser útil para evitar exposição desnecessária.

Sem endereço de host explícito:

```bash
-p 8080:80
```

Docker publica normalmente a porta nas interfaces configuradas para o binding por omissão.

> **Implicação de segurança**  
> Publicar uma porta é uma decisão de exposição de rede. Não publique portas apenas “porque a aplicação as tem”. Publique apenas o que precisa realmente de ser acessível fora da rede interna de containers.

## 4.3. Porta interna vs. porta publicada

```text
PostgreSQL
container port: 5432
```

Se apenas outra aplicação na mesma rede Docker precisa de contactar PostgreSQL, não é necessário publicar `5432` no host.

Em muitas arquiteturas:

```text
Browser
   │
   ▼
host:8080
   │
   ▼
app:80
   │
   │ rede Docker interna
   ▼
db:5432
```

A base de dados permanece apenas na rede Docker.

## 4.4. Ver mapeamentos

```bash
docker ps
```

ou:

```bash
docker port web
```

Também podem ser consultados via:

```bash
docker inspect web
```

---

# 5. Logs e observação

Uma regra operacional importante é:

```text
Observar primeiro
Alterar depois
```

Muitos problemas tornam-se mais difíceis porque se começa imediatamente a recriar containers, alterar portas ou modificar ficheiros sem recolher evidências.

## 5.1. Consultar logs

```bash
docker logs web
```

Seguir logs:

```bash
docker logs -f web
```

Últimas 50 linhas:

```bash
docker logs --tail 50 web
```

Com timestamps:

```bash
docker logs -t web
```

Desde um período relativo:

```bash
docker logs --since 10m web
```

## 5.2. De onde vêm estes logs?

No modelo habitual de containers, as aplicações escrevem logs para:

- standard output (`stdout`);
- standard error (`stderr`).

Docker captura estas streams através do mecanismo de logging configurado.

Isto permite consultar:

```bash
docker logs CONTAINER
```

sem entrar no container.

## 5.3. Logs não são o mesmo que estado

Um container pode estar:

```text
Running
```

e a aplicação estar a devolver erros.

Também pode estar:

```text
Exited
```

e os logs explicarem a causa.

Por isso uma sequência útil é:

```bash
docker ps -a
docker logs CONTAINER
```

## 5.4. Logs e persistência

Os logs do runtime não devem ser confundidos com dados persistentes da aplicação.

Um sistema de produção pode necessitar de:

- rotação;
- retenção;
- agregação;
- indexação;
- pesquisa;
- controlo de volume.

O comando `docker logs` é uma ferramenta operacional importante, mas não constitui por si só uma arquitetura completa de observabilidade.

---

# 6. `docker exec`

`docker exec` inicia um novo processo dentro de um container que já está em execução.

Exemplo:

```bash
docker exec -it web sh
```

Se a imagem tiver Bash:

```bash
docker exec -it web bash
```

## 6.1. O que realmente acontece?

Não “entramos no container” no sentido de iniciar uma máquina virtual.

Conceptualmente:

```text
Container já em execução
      │
      ├── processo principal
      │
      └── docker exec
             │
             ▼
       novo processo
       no mesmo contexto
       do container
```

O novo processo utiliza os namespaces e ambiente apropriado do container.

## 6.2. Opções `-i` e `-t`

```text
-i
└── mantém stdin disponível

-t
└── atribui pseudo-terminal
```

Por isso são usados frequentemente em conjunto:

```bash
-it
```

## 6.3. Executar um comando sem shell interativa

```bash
docker exec web ps aux
```

ou:

```bash
docker exec db psql --version
```

Isto pode ser preferível a abrir uma shell e executar vários passos manualmente.

## 6.4. `exec` como ferramenta de diagnóstico

Útil para:

- verificar ficheiros;
- testar resolução DNS;
- consultar processos;
- confirmar environment variables;
- validar conectividade;
- executar ferramentas administrativas presentes na imagem.

Não deve tornar-se no método normal para “corrigir” permanentemente um container.

Se fizermos:

```bash
docker exec web sh
```

e alterarmos manualmente um ficheiro dentro da writable layer, essa alteração:

- não altera a imagem;
- pode perder-se quando o container for recriado;
- não fica representada de forma reproduzível.

O princípio operacional correto é:

```text
diagnóstico manual
      │
      ▼
identificar causa
      │
      ▼
corrigir configuração/artefacto
      │
      ▼
recriar de forma reproduzível
```

---

# 7. `docker inspect`

`docker inspect` é uma das ferramentas mais importantes para compreender **o que Docker realmente configurou**.

```bash
docker inspect web
```

Devolve dados estruturados em JSON.

## 7.1. Informação útil

Podemos encontrar:

- imagem;
- comando;
- environment;
- estado;
- exit code;
- mounts;
- portas;
- networks;
- endereços IP;
- restart policy;
- labels.

## 7.2. Separar `Config`, `HostConfig` e `NetworkSettings`

Sem decorar toda a estrutura, é útil reconhecer áreas conceptuais.

```text
Config
├── Env
├── Cmd
├── Entrypoint
└── Image

HostConfig
├── PortBindings
├── Binds
├── RestartPolicy
└── recursos

Mounts
└── volumes / bind mounts

NetworkSettings
├── Ports
└── Networks
```

## 7.3. Formatar resultados

Exemplo para obter o IP numa rede:

```bash
docker inspect \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  web
```

Ver mounts:

```bash
docker inspect \
  --format '{{json .Mounts}}' \
  web
```

O output JSON pode ser combinado com ferramentas como `jq`, quando disponíveis.

## 7.4. O valor de `inspect` no troubleshooting

Imagine:

```text
“A aplicação não está a escrever no volume esperado.”
```

Antes de alterar o container:

```bash
docker inspect app
```

e procurar `Mounts`.

Ou:

```text
“Os containers não comunicam.”
```

Confirmar:

```bash
docker inspect app
docker inspect db
```

e verificar se pertencem à mesma rede.

---

# 8. `docker stats` e recursos

Docker permite observar utilização de recursos:

```bash
docker stats
```

Para obter uma única amostra:

```bash
docker stats --no-stream
```

Um container específico:

```bash
docker stats --no-stream web
```

## 8.1. Métricas habitualmente apresentadas

Podem incluir:

- CPU;
- memória;
- limite de memória;
- percentagem de memória;
- tráfego de rede;
- I/O de bloco;
- número de processos.

## 8.2. Estado não é consumo

`docker ps` responde sobretudo:

```text
Está a correr?
```

`docker stats` ajuda a responder:

```text
Que recursos está a consumir?
```

São perguntas diferentes.

## 8.3. Como interpretar

Um valor elevado não significa automaticamente um problema.

É necessário considerar:

- carga atual;
- limites configurados;
- comportamento histórico;
- tipo de aplicação;
- resposta a pedidos;
- crescimento de consumo ao longo do tempo.

Exemplo:

```text
CPU = 90%
```

pode ser normal num processamento intensivo.

Mas:

```text
Memória cresce continuamente
sem regressar
```

pode justificar investigação.

## 8.4. Container sem limites

Um container sem limites explícitos pode competir com outros processos pelos recursos do host.

A configuração detalhada de políticas de recursos pode variar com a plataforma, versão e contexto de execução, mas a observação com `stats` ajuda a tornar visível o comportamento efetivo.

---

# 9. Networking Docker

Cada container ligado a uma rede Docker recebe configuração de rede própria.

Num cenário Linux simplificado:

```text
Processo no container
       │
       ▼
network namespace
       │
       ▼
interface virtual
       │
       ▼
veth
       │
       ▼
bridge no host
       │
       ▼
rede do host
```

O **network namespace** permite que o container veja o seu próprio conjunto de:

- interfaces;
- endereços;
- rotas;
- sockets;
- regras de rede relacionadas com o namespace.

## 9.1. Drivers de rede

Listar redes:

```bash
docker network ls
```

Em instalações típicas aparecem redes como:

```text
bridge
host
none
```

A formação concentra-se sobretudo em `bridge`.

## 9.2. Rede do host vs. rede do container

Um erro frequente é assumir:

```text
localhost no container
=
localhost no host
```

Não é verdade.

Dentro de um container:

```text
127.0.0.1
```

refere-se ao loopback do namespace de rede do próprio container.

Dois containers diferentes possuem contextos de rede distintos.

---

# 10. Bridge networks

A rede bridge é o modelo fundamental de networking single-host em Docker.

## 10.1. Bridge default

Docker cria normalmente uma rede chamada:

```text
bridge
```

Containers sem `--network` explícito são, em muitos cenários, associados à bridge default.

Consultar:

```bash
docker network inspect bridge
```

## 10.2. Criar uma user-defined bridge

```bash
docker network create app-network
```

Confirmar:

```bash
docker network ls
```

Inspecionar:

```bash
docker network inspect app-network
```

## 10.3. Porque criar uma rede própria?

User-defined bridge networks oferecem vantagens importantes:

- isolamento lógico entre grupos de containers;
- resolução DNS automática por nome;
- configuração independente;
- possibilidade de ligar/desligar containers durante a sua execução.

Exemplo:

```bash
docker network create app-network

docker run -d \
  --name db \
  --network app-network \
  postgres:16
```

Outro container na mesma rede pode contactar o serviço pelo nome `db`, desde que a aplicação e o serviço estejam corretamente configurados.

## 10.4. Ligar um container existente

```bash
docker network connect app-network web
```

Desligar:

```bash
docker network disconnect app-network web
```

Um container pode estar ligado a mais do que uma rede.

## 10.5. Isolamento entre bridges

Conceptualmente:

```text
bridge-a
├── app-a
└── db-a

bridge-b
├── app-b
└── db-b
```

Por omissão, o desenho deve assumir isolamento entre redes diferentes e só introduzir conectividade quando necessário.

---

# 11. DNS e comunicação entre containers

Uma das vantagens mais importantes das user-defined bridge networks é a resolução de nomes.

## 11.1. Evitar IPs fixos de containers

Não é boa prática operacional depender de:

```text
172.18.0.4
```

como identidade de um serviço.

Ao recriar um container, o endereço pode mudar.

Em vez disso:

```text
app
 │
 │ db:5432
 ▼
DNS Docker
 │
 ▼
IP atual de db
```

## 11.2. Exemplo de resolução

Criar rede:

```bash
docker network create demo-net
```

Criar um servidor:

```bash
docker run -d \
  --name web \
  --network demo-net \
  nginx
```

A partir de outro container na mesma rede, o nome `web` pode ser resolvido.

Exemplo com uma imagem que possua uma ferramenta HTTP:

```bash
docker run --rm \
  --network demo-net \
  curlimages/curl \
  http://web
```

O ponto central não é a imagem `curlimages/curl`, mas o mecanismo:

```text
nome lógico do container/serviço
           │
           ▼
embedded DNS
           │
           ▼
endereço atual
```

## 11.3. Comunicação interna não requer `-p`

Dois containers na mesma user-defined bridge podem comunicar usando as portas internas disponibilizadas pelo serviço.

`-p` é necessário quando se pretende tornar uma porta acessível através do host, não simplesmente para comunicação container-to-container na mesma rede.

Isto permite manter serviços internos sem exposição desnecessária.

---

# 12. Filesystem do container

Um container criado a partir de uma imagem vê:

```text
layers read-only da imagem
          +
writable layer do container
          =
filesystem apresentado ao processo
```

## 12.1. Writable layer

Se a aplicação criar:

```text
/tmp/ficheiro.txt
```

ou alterar um ficheiro fora de um mount, a alteração fica na writable layer do container.

Essa writable layer está associada ao objeto container.

Remover o container remove também essa layer.

## 12.2. Consequência operacional

Considere:

```bash
docker run --name teste alpine \
  sh -c 'echo importante > /dados.txt'
```

Se depois:

```bash
docker rm teste
```

e criar outro container a partir da mesma imagem, o novo container não recebe a writable layer do anterior.

A imagem continua intacta.

## 12.3. Três categorias úteis

```text
1. Image layers
   read-only

2. Container writable layer
   associada ao ciclo de vida do container

3. Mounts
   armazenamento com lifecycle separado ou origem externa
```

Esta distinção é essencial para compreender persistência.

---

# 13. Bind mounts

Um bind mount liga diretamente um caminho existente do host a um caminho dentro do container.

Exemplo:

```bash
docker run --rm \
  --mount type=bind,src="$PWD",dst=/dados \
  alpine \
  ls -la /dados
```

## 13.1. Modelo

```text
Host
/home/user/projeto
        │
        │ bind mount
        ▼
Container
/app
```

O container vê os ficheiros do host no destino montado.

## 13.2. Casos de utilização

Bind mounts são úteis quando é necessário:

- editar ficheiros no host e vê-los no container;
- montar configuração;
- partilhar código durante desenvolvimento;
- gerar output diretamente para um diretório do host.

## 13.3. `--mount` vs. `-v`

Formas comuns:

```bash
docker run \
  --mount type=bind,src=/origem,dst=/destino \
  imagem
```

ou:

```bash
docker run \
  -v /origem:/destino \
  imagem
```

`--mount` é mais explícito e geralmente facilita a leitura e redução de ambiguidades.

## 13.4. Riscos operacionais

Um bind mount cria acoplamento ao host:

```text
container
   │
   ▼
/caminho/específico/no/host
```

Se o mesmo caminho não existir noutra máquina, a configuração pode falhar ou comportar-se de forma diferente.

Há também uma implicação de segurança: dependendo das permissões e do modo de montagem, um processo no container pode modificar ficheiros do host.

Quando só é necessária leitura, deve considerar-se uma montagem read-only:

```bash
docker run \
  --mount type=bind,src=/config,dst=/config,readonly \
  imagem
```

---

# 14. Named volumes

Um named volume é um objeto gerido por Docker.

Criar:

```bash
docker volume create dados
```

Listar:

```bash
docker volume ls
```

Inspecionar:

```bash
docker volume inspect dados
```

Remover:

```bash
docker volume rm dados
```

## 14.1. Montar num container

```bash
docker run --rm \
  --mount type=volume,src=dados,dst=/dados \
  alpine \
  sh -c 'echo persistente > /dados/teste.txt'
```

Depois:

```bash
docker run --rm \
  --mount type=volume,src=dados,dst=/dados \
  alpine \
  cat /dados/teste.txt
```

Resultado esperado:

```text
persistente
```

O primeiro container já não existe.

O volume existe independentemente dele.

## 14.2. Modelo mental

```text
Container A
    │
    ▼
Volume dados
    ▲
    │
Container B
```

O volume não pertence conceptualmente ao container A.

É um objeto separado que pode ser montado por containers.

## 14.3. Volume vs. bind mount

| Aspeto | Named volume | Bind mount |
|---|---|---|
| Gestão | Docker | administrador/utilizador |
| Origem | storage gerido por Docker | caminho explícito no host |
| Portabilidade | geralmente superior | dependente da estrutura do host |
| Acesso direto pelo utilizador | menos necessário | natural |
| Uso típico | dados persistentes da aplicação | código/configuração/ficheiros do host |

## 14.4. Named volume para PostgreSQL

PostgreSQL guarda os seus dados num diretório dentro do filesystem do container.

Se esse diretório estiver associado apenas à writable layer:

```text
remover container
       │
       ▼
perder writable layer
```

Quando montamos um volume:

```text
PostgreSQL
   │
   ▼
/var/lib/postgresql/data
   │
   ▼
named volume
```

a identidade do armazenamento deixa de estar acoplada ao container individual.

---

# 15. Persistência não é backup

É uma distinção essencial:

```text
Persistência
≠
Backup
```

## 15.1. O que resolve a persistência?

Persistência permite que dados sobrevivam a operações como:

- recriar container;
- substituir container;
- atualizar imagem;
- reiniciar serviço.

## 15.2. O que um volume não resolve sozinho?

Se a aplicação ou utilizador executar:

```sql
DROP TABLE dados_importantes;
```

a alteração é persistida no volume.

Se houver:

- corrupção;
- erro lógico;
- ransomware;
- eliminação do volume;
- falha física;
- erro administrativo;

a existência do volume não fornece automaticamente uma cópia recuperável.

## 15.3. Backup implica outra cópia ou estratégia de recuperação

Um backup adequado envolve decisões como:

- frequência;
- retenção;
- localização;
- consistência;
- cifragem;
- testes de restore;
- RPO;
- RTO.

Para uma base de dados, backup lógico e backup do storage têm propriedades distintas.

A mensagem operacional a reter é:

```text
Volume
└── mantém dados fora do lifecycle do container

Backup
└── permite recuperar estado a partir de uma cópia/estratégia independente
```

---

# 16. Docker Compose

À medida que aumentam os containers, comandos individuais tornam-se difíceis de reproduzir.

Imagine:

```bash
docker network create app-net
docker volume create db-data
docker run ...
docker run ...
```

Para uma aplicação multi-container, Docker Compose permite representar a configuração num ficheiro declarativo.

Normalmente:

```text
compose.yaml
```

## 16.1. Do imperativo ao declarativo

Abordagem imperativa:

```text
criar rede
criar volume
criar db
criar app
ligar tudo
publicar porta
```

Abordagem Compose:

```yaml
services:
  ...
networks:
  ...
volumes:
  ...
```

e:

```bash
docker compose up -d
```

## 16.2. Estrutura base

```yaml
services:
  web:
    image: nginx

networks:
  default:

volumes:
  dados:
```

As chaves principais mais importantes neste contexto são:

```text
services
networks
volumes
```

## 16.3. Compose project

Compose agrupa recursos num projeto.

Isto ajuda a manter relação entre:

- containers;
- networks;
- volumes;
- nomes dos recursos.

O nome do projeto pode resultar do diretório/configuração ou ser definido explicitamente.

Exemplo:

```bash
docker compose -p demo up -d
```

## 16.4. Validar configuração

Antes de iniciar:

```bash
docker compose config
```

Este comando é extremamente importante.

Permite observar a configuração resultante depois de:

- processar o YAML;
- resolver variáveis;
- combinar defaults;
- interpretar o ficheiro.

---

# 17. Services em Compose

Um `service` descreve a forma como um componente da aplicação deve ser executado.

Exemplo:

```yaml
services:
  web:
    image: nginx:1.27
    ports:
      - "8080:80"
```

## 17.1. Service não é exatamente container

É útil distinguir:

```text
Service Compose
      │
      ▼
definição/configuração
      │
      ▼
container(s) criado(s)
```

No uso normal single-host, um service origina tipicamente um container, mas conceptualmente o service é a definição.

## 17.2. Configuração típica

```yaml
services:
  app:
    image: minha-app:1.0
    ports:
      - "8080:80"
    environment:
      APP_ENV: production
    networks:
      - app-network
```

A configuração descreve:

- artefacto;
- conectividade;
- runtime environment;
- exposição;
- dependências;
- storage.

## 17.3. Nome do service e DNS

Em Compose, services numa rede comum podem normalmente usar o nome do service como hostname lógico.

Assim:

```text
service app
    │
    │ db:5432
    ▼
service db
```

Em vez de codificar o IP de um container específico.

---

# 18. Networks em Compose

Compose pode criar networks automaticamente.

Exemplo:

```yaml
services:
  app:
    image: minha-app
    networks:
      - app-network

  db:
    image: postgres:16
    networks:
      - app-network

networks:
  app-network:
```

## 18.1. Relação

```text
Compose project
      │
      ▼
app-network
  ├── app
  └── db
```

## 18.2. Service discovery

O service `app` pode usar:

```text
db
```

para contactar o service `db`.

Exemplo:

```text
postgresql://utilizador:password@db:5432/base
```

O elemento importante é:

```text
@db:5432
```

`db` é um nome lógico resolvido dentro da rede.

## 18.3. Não publicar a base de dados sem necessidade

Este ficheiro:

```yaml
services:
  db:
    image: postgres:16
```

não precisa de:

```yaml
ports:
  - "5432:5432"
```

se apenas a aplicação Compose necessita de contactar PostgreSQL internamente.

Isto reduz a superfície exposta no host.

---

# 19. Volumes em Compose

Volumes podem ser declarados no nível superior:

```yaml
volumes:
  db-data:
```

e associados a um service:

```yaml
services:
  db:
    image: postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data
```

## 19.1. Modelo

```text
service db
     │
     ▼
container PostgreSQL
     │
     ▼
/var/lib/postgresql/data
     │
     ▼
volume db-data
```

## 19.2. `docker compose down`

Por omissão:

```bash
docker compose down
```

remove recursos como containers e network do projeto, mas não deve ser confundido com uma ordem genérica para apagar todos os dados persistentes.

Quando se utiliza:

```bash
docker compose down -v
```

pede-se também remoção dos volumes associados ao projeto.

Por isso `-v` merece atenção.

Num ambiente com dados:

```text
down
```

e:

```text
down -v
```

não representam a mesma intenção operacional.

## 19.3. Inspecionar o volume criado

```bash
docker volume ls
```

Compose costuma aplicar naming do projeto aos recursos geridos.

Pode também usar:

```bash
docker compose config
```

para perceber a definição efetiva e:

```bash
docker volume inspect NOME
```

para examinar o volume concreto.

---

# 20. Variáveis e configuração

Compose suporta interpolação de variáveis.

Exemplo:

```yaml
services:
  app:
    image: ${SYMFONY_IMAGE}
    ports:
      - "${APP_PORT:-8080}:80"
```

## 20.1. `.env`

Um ficheiro `.env` pode fornecer valores utilizados pelo Compose.

Exemplo:

```dotenv
APP_PORT=8080
APP_ENV=dev
```

No YAML:

```yaml
environment:
  APP_ENV: ${APP_ENV:-dev}
```

## 20.2. Default com `:-`

```text
${APP_PORT:-8080}
```

significa conceptualmente:

```text
se APP_PORT estiver definido e utilizável
    usar valor
caso contrário
    usar 8080
```

## 20.3. Ver configuração resolvida

```bash
docker compose config
```

Antes de iniciar a aplicação, este comando ajuda a detetar:

- variáveis em falta;
- erros de estrutura;
- valores inesperados;
- substituições incorretas.

## 20.4. `.env` não é secret manager

Um ficheiro `.env` é uma conveniência de configuração.

Pode conter valores sensíveis em claro.

Boas práticas incluem:

- não fazer commit de `.env` com credenciais reais;
- fornecer `.env.example` sem segredos reais;
- restringir permissões;
- utilizar mecanismos apropriados para segredos em ambientes de produção.

---

# 21. Dependências e healthchecks

Uma aplicação pode depender de outro serviço.

Exemplo:

```text
Symfony
   │
   ▼
PostgreSQL
```

Mas existem duas questões diferentes:

```text
1. O processo PostgreSQL foi iniciado?
2. PostgreSQL está pronto para aceitar ligações?
```

Não são equivalentes.

## 21.1. `depends_on`

Exemplo simples:

```yaml
services:
  app:
    depends_on:
      - db
```

Expressa uma relação de dependência/ordenação.

## 21.2. `service_healthy`

Com sintaxe longa:

```yaml
services:
  app:
    depends_on:
      db:
        condition: service_healthy
```

e um healthcheck no service `db`:

```yaml
services:
  db:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d database"]
      interval: 5s
      timeout: 3s
      retries: 10
```

Compose pode esperar que a dependência marcada com `service_healthy` passe o healthcheck antes de criar/iniciar a dependência na ordem prevista pela configuração atual.

## 21.3. Healthcheck não é garantia absoluta da aplicação

Um healthcheck é tão bom quanto a condição que testa.

Exemplo:

```text
processo existe
```

é mais fraco do que:

```text
base de dados aceita ligação
```

e ambos podem ser diferentes de:

```text
toda a aplicação consegue executar uma operação de negócio
```

Logo:

```text
healthcheck
=
sinal operacional definido por nós
```

Não é uma prova universal de correção.

## 21.4. Exemplo PostgreSQL

`pg_isready` é útil para testar disponibilidade do servidor PostgreSQL.

Exemplo:

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
    ]
```

Este teste pergunta ao servidor se está disponível para ligações.

---

# 22. Ciclo de vida com Compose

## 22.1. Iniciar

Em foreground:

```bash
docker compose up
```

Em background:

```bash
docker compose up -d
```

## 22.2. Ver estado

```bash
docker compose ps
```

Incluir containers parados:

```bash
docker compose ps -a
```

## 22.3. Logs

Todos os services:

```bash
docker compose logs
```

Seguir:

```bash
docker compose logs -f
```

Service específico:

```bash
docker compose logs -f db
```

## 22.4. Executar comando num service

```bash
docker compose exec app sh
```

ou:

```bash
docker compose exec db psql --version
```

## 22.5. Parar sem remover

```bash
docker compose stop
```

Retomar:

```bash
docker compose start
```

## 22.6. Derrubar projeto

```bash
docker compose down
```

Remove os containers e redes geridos de acordo com a operação.

Para remover também volumes:

```bash
docker compose down -v
```

Antes de utilizar `-v`, é essencial compreender o impacto sobre os dados.

## 22.7. Recriação

Se a configuração ou imagem de um service mudar, um novo:

```bash
docker compose up -d
```

pode recriar containers para aplicar a nova configuração, preservando volumes montados.

Esta é uma das razões pelas quais é importante separar:

```text
container
```

de:

```text
dados persistentes
```

---

# 23. Caso prático — Symfony Demo e PostgreSQL

Este caso utiliza uma aplicação Symfony já containerizada e uma base de dados PostgreSQL 16.

A imagem da aplicação é:

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
```

A arquitetura é:

```text
Browser
   │
   │ host:8080
   ▼
┌─────────────────────┐
│ Symfony Demo        │
│ service: app        │
│ container port: 80  │
└──────────┬──────────┘
           │
           │ app-network
           │ db:5432
           ▼
┌─────────────────────┐
│ PostgreSQL 16       │
│ service: db         │
│ port: 5432          │
└──────────┬──────────┘
           │
           ▼
       db-data
       volume
```

## 23.1. Ficheiro `.env`

Criar `.env` a partir do exemplo:

```bash
cp .env.example .env
```

Conteúdo de referência:

```dotenv
SYMFONY_IMAGE=ghcr.io/skullclamp/symfony-demo:1.0.0

APP_PORT=8080
APP_ENV=dev
APP_VERSION=1.0.0
APP_SECRET=lab-only-change-me

POSTGRES_DB=symfony
POSTGRES_USER=symfony
POSTGRES_PASSWORD=lab-symfony

DATABASE_URL=postgresql://symfony:lab-symfony@db:5432/symfony?serverVersion=16&charset=utf8
```

Estes valores são adequados apenas a um contexto pedagógico controlado.

Repare em:

```text
@db:5432
```

A aplicação aponta para o **nome do service** `db`, não para um IP fixo.

## 23.2. Ficheiro `compose.yaml`

```yaml
services:
  app:
    image: ${SYMFONY_IMAGE}
    ports:
      - "${APP_PORT:-8080}:80"
    environment:
      APP_ENV: ${APP_ENV:-dev}
      APP_VERSION: ${APP_VERSION:-1.0.0}
      APP_SECRET: ${APP_SECRET}
      DATABASE_URL: ${DATABASE_URL}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
        ]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 5s
    networks:
      - app-network

networks:
  app-network:

volumes:
  db-data:
```

## 23.3. Antes de arrancar: validar

```bash
docker compose config
```

Procure:

- imagem final utilizada;
- porta final;
- variáveis;
- network;
- volume;
- dependência;
- healthcheck.

Se existir uma variável obrigatória em falta, é preferível descobri-lo antes de iniciar os services.

## 23.4. Obter imagens

Pode deixar que `up` obtenha as imagens necessárias ou executar:

```bash
docker compose pull
```

Observar:

```bash
docker image ls
```

## 23.5. Iniciar

```bash
docker compose up -d
```

Observar estado:

```bash
docker compose ps
```

O PostgreSQL pode passar por estados de inicialização antes de ficar healthy.

## 23.6. Observar logs

Base de dados:

```bash
docker compose logs db
```

Aplicação:

```bash
docker compose logs app
```

Seguir ambos:

```bash
docker compose logs -f
```

## 23.7. Confirmar publicação da aplicação

```bash
docker compose ps
```

Deverá ser visível uma relação equivalente a:

```text
0.0.0.0:8080->80/tcp
```

Aceder:

```text
http://localhost:8080
```

ou ao endereço do host usado no ambiente.

## 23.8. Confirmar que PostgreSQL não foi publicado

No `compose.yaml` do exemplo, o service `db` não tem:

```yaml
ports:
```

Isto é deliberado.

A aplicação comunica internamente:

```text
app
 │
 │ db:5432
 ▼
db
```

Não é necessário tornar PostgreSQL acessível externamente para esta arquitetura.

## 23.9. Inspecionar a network

Listar:

```bash
docker network ls
```

Compose cria um nome físico associado ao projeto.

Inspecionar:

```bash
docker network inspect NOME_DA_NETWORK
```

Procurar:

- subnet;
- gateway;
- containers;
- endereços IP.

## 23.10. Testar resolução por nome

Entrar no container da aplicação, se a imagem tiver shell e ferramentas adequadas:

```bash
docker compose exec app sh
```

Dentro, observar configuração DNS:

```bash
cat /etc/resolv.conf
```

O teste exato de DNS depende das ferramentas incluídas na imagem. O conceito a confirmar é:

```text
db
  │
  ▼
service discovery
  │
  ▼
container atual do service db
```

## 23.11. Inspecionar mounts

Obter o container de PostgreSQL:

```bash
docker compose ps
```

Depois:

```bash
docker inspect NOME_DO_CONTAINER_DB
```

Procurar `Mounts`.

Deverá existir relação entre:

```text
db-data
```

e:

```text
/var/lib/postgresql/data
```

## 23.12. Ver o volume

```bash
docker volume ls
```

Inspecionar:

```bash
docker volume inspect NOME_DO_VOLUME
```

## 23.13. Criar um dado de teste

Podemos utilizar `psql` dentro do service `db`.

Criar uma tabela simples:

```bash
docker compose exec db \
  psql -U symfony -d symfony \
  -c "CREATE TABLE IF NOT EXISTS lab_marker (id integer PRIMARY KEY, valor text);"
```

Inserir:

```bash
docker compose exec db \
  psql -U symfony -d symfony \
  -c "INSERT INTO lab_marker (id, valor) VALUES (1, 'persistencia-ok') ON CONFLICT (id) DO UPDATE SET valor = EXCLUDED.valor;"
```

Consultar:

```bash
docker compose exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Resultado esperado contém:

```text
persistencia-ok
```

## 23.14. Recriar o container da base de dados

Forçar recriação do service `db`:

```bash
docker compose up -d --force-recreate db
```

Aguardar:

```bash
docker compose ps
```

Consultar novamente:

```bash
docker compose exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

Se o volume foi corretamente mantido:

```text
container anterior
     │ removido/substituído
     ▼
volume db-data
     │ mantido
     ▼
container novo
     │
     ▼
dados ainda existem
```

## 23.15. Parar e voltar a iniciar

```bash
docker compose stop
```

Confirmar:

```bash
docker compose ps -a
```

Depois:

```bash
docker compose start
```

## 23.16. `down` sem apagar volume

```bash
docker compose down
```

Depois:

```bash
docker volume ls
```

Voltar a criar:

```bash
docker compose up -d
```

Confirmar o dado:

```bash
docker compose exec db \
  psql -U symfony -d symfony \
  -c "SELECT * FROM lab_marker;"
```

## 23.17. Atenção a `down -v`

```bash
docker compose down -v
```

pede remoção dos volumes do projeto.

Num cenário em que `db-data` contém os únicos dados da base de dados, esta operação deve ser tratada como destrutiva.

## 23.18. O que este caso demonstra

```text
Imagem Symfony
      │
      ▼
service app
      │
      ├── environment
      ├── port 8080:80
      └── app-network
             │
             ▼
          service db
             │
             ├── healthcheck
             └── db-data
```

E permite observar, de forma concreta:

```text
imagem ≠ container
porta interna ≠ porta publicada
IP ≠ identidade de serviço
writable layer ≠ volume
persistência ≠ backup
service started ≠ service healthy
Compose file ≠ sequência manual de docker run
```

---

# 24. Troubleshooting operacional

Um método simples e disciplinado evita alterações aleatórias.

```text
1. Estado
   ↓
2. Logs
   ↓
3. Configuração efetiva
   ↓
4. Network / mounts
   ↓
5. Execução interna, se necessário
   ↓
6. Recursos
   ↓
7. Hipótese
   ↓
8. Alteração controlada
```

## 24.1. Container terminou inesperadamente

Começar:

```bash
docker ps -a
```

Depois:

```bash
docker logs CONTAINER
```

Ver exit code:

```bash
docker inspect CONTAINER \
  --format '{{.State.ExitCode}}'
```

Ver estado completo:

```bash
docker inspect CONTAINER
```

Perguntas:

```text
O processo principal terminou?
Houve erro da aplicação?
A configuração está presente?
O mount existe?
A dependência está disponível?
```

## 24.2. Porta já está ocupada

Sintoma:

```text
bind: address already in use
```

Confirmar a porta que se pretende publicar.

Exemplo:

```yaml
ports:
  - "8080:80"
```

Alternativas:

- parar o processo que já utiliza a porta;
- escolher outra porta do host;
- alterar `APP_PORT`.

Por exemplo:

```dotenv
APP_PORT=8081
```

Depois:

```bash
docker compose up -d
```

## 24.3. Aplicação não comunica com a base de dados

Ver estado:

```bash
docker compose ps
```

Logs:

```bash
docker compose logs db
docker compose logs app
```

Configuração:

```bash
docker compose config
```

Rede:

```bash
docker network ls
docker network inspect NOME
```

Questões:

```text
Os dois services estão na mesma network?
DATABASE_URL aponta para "db"?
PostgreSQL está healthy?
As credenciais coincidem?
O nome da base de dados coincide?
```

## 24.4. Volume não contém os dados esperados

Ver definição:

```bash
docker compose config
```

Ver volumes:

```bash
docker volume ls
```

Ver mount no container:

```bash
docker inspect CONTAINER
```

Confirmar:

```text
source do mount
destination do mount
tipo do mount
```

Um erro típico é escrever dados fora do diretório montado.

## 24.5. Variáveis não têm o valor esperado

```bash
docker compose config
```

é o primeiro comando recomendado.

Depois, se necessário:

```bash
docker compose exec app env
```

ou:

```bash
docker inspect CONTAINER
```

Lembre-se:

```text
valor no .env
      │
      ▼
interpolação Compose
      │
      ▼
configuração resultante
      │
      ▼
environment no container
```

São etapas distintas.

## 24.6. `exec` falha porque não existe Bash

Muitas imagens mínimas não incluem:

```text
bash
```

Tentar:

```bash
docker exec -it CONTAINER sh
```

Mesmo `sh` pode não existir em imagens extremamente minimalistas.

Isso não significa necessariamente que o container esteja avariado.

## 24.7. Sequência curta de diagnóstico

Para Docker:

```bash
docker ps -a
docker logs CONTAINER
docker inspect CONTAINER
docker stats --no-stream
```

Para Compose:

```bash
docker compose config
docker compose ps -a
docker compose logs
docker compose logs SERVICE
```

Depois aprofundar:

```bash
docker network inspect NETWORK
docker volume inspect VOLUME
docker compose exec SERVICE sh
```

---

# 25. Síntese

A operação de containers Docker assenta em várias separações conceptuais.

```text
Imagem
≠
Container
```

```text
Container running
≠
Aplicação saudável
```

```text
Porta do container
≠
Porta publicada no host
```

```text
IP do container
≠
Identidade estável do serviço
```

```text
Writable layer
≠
Volume
```

```text
Persistência
≠
Backup
```

```text
docker exec
≠
configuração reproduzível
```

```text
depends_on: service_started
≠
readiness real
```

```text
Compose
=
descrição declarativa de uma aplicação multi-container
```

O fluxo operacional completo pode ser resumido como:

```text
Registry
   │
   ▼
Imagem
   │
   ▼
Container
   │
   ├── estado
   ├── logs
   ├── recursos
   ├── network
   └── mounts
          │
          ▼
Docker Compose
   │
   ├── services
   ├── networks
   ├── volumes
   ├── environment
   └── dependencies
          │
          ▼
Aplicação multi-container reproduzível
```

---

# 26. Guia rápido Docker

## Imagens

```bash
docker pull IMAGE
docker image ls
docker image inspect IMAGE
```

## Containers

```bash
docker run IMAGE
docker run -d IMAGE
docker run --rm IMAGE
docker run --name NOME IMAGE

docker ps
docker ps -a

docker stop NOME
docker start NOME
docker restart NOME
docker rm NOME
docker rm -f NOME
```

## Portas

```bash
docker run -d -p 8080:80 IMAGE
docker run -d -p 127.0.0.1:8080:80 IMAGE
docker port NOME
```

## Logs

```bash
docker logs NOME
docker logs -f NOME
docker logs --tail 50 NOME
docker logs --since 10m NOME
```

## Exec

```bash
docker exec NOME COMANDO
docker exec -it NOME sh
docker exec -it NOME bash
```

## Inspect

```bash
docker inspect NOME
```

## Recursos

```bash
docker stats
docker stats --no-stream
docker stats --no-stream NOME
```

## Networks

```bash
docker network ls
docker network create NOME
docker network inspect NOME
docker network connect REDE CONTAINER
docker network disconnect REDE CONTAINER
docker network rm NOME
```

## Volumes

```bash
docker volume create NOME
docker volume ls
docker volume inspect NOME
docker volume rm NOME
```

---

# 27. Guia rápido Docker Compose

## Validar configuração

```bash
docker compose config
```

## Obter imagens

```bash
docker compose pull
```

## Iniciar

```bash
docker compose up
docker compose up -d
```

## Estado

```bash
docker compose ps
docker compose ps -a
```

## Logs

```bash
docker compose logs
docker compose logs -f
docker compose logs SERVICE
docker compose logs -f SERVICE
```

## Executar comando

```bash
docker compose exec SERVICE COMANDO
docker compose exec SERVICE sh
```

## Parar sem remover

```bash
docker compose stop
```

## Iniciar novamente

```bash
docker compose start
```

## Recriar

```bash
docker compose up -d --force-recreate SERVICE
```

## Remover containers e rede do projeto

```bash
docker compose down
```

## Remover também volumes

```bash
docker compose down -v
```

Use `-v` apenas quando pretende realmente remover os volumes associados.

---

# 28. Glossário

| Termo | Definição |
|---|---|
| **Bind mount** | Associação direta entre um caminho do host e um caminho no container. |
| **Bridge network** | Rede software single-host que permite comunicação entre containers ligados à mesma bridge. |
| **Compose** | Modelo e ferramenta para definir e gerir aplicações multi-container através de ficheiros declarativos. |
| **Compose project** | Agrupamento lógico dos recursos geridos conjuntamente por uma configuração Compose. |
| **Container** | Instância de execução criada a partir de uma imagem e configurada com runtime, rede, mounts e outras opções. |
| **Container port** | Porta em que um processo do container escuta dentro do seu contexto de rede. |
| **Detached mode** | Execução em background, normalmente ativada com `-d`. |
| **DNS** | Sistema de resolução de nomes; Docker fornece DNS embebido em user-defined networks. |
| **Environment variable** | Par nome/valor disponibilizado ao processo e usado frequentemente para configuração. |
| **Exit code** | Código devolvido pelo processo quando termina. `0` costuma representar sucesso por convenção Unix, outros valores indicam condições específicas da aplicação. |
| **Healthcheck** | Teste periódico usado para determinar um estado de saúde definido para um container/service. |
| **Host port** | Porta do host usada numa publicação/mapeamento para um container. |
| **Image** | Artefacto read-only composto por layers e metadata usado para criar containers. |
| **Mount** | Mecanismo que disponibiliza storage ou um caminho externo dentro do filesystem do container. |
| **Named volume** | Volume com nome, criado e gerido por Docker, com lifecycle independente do container. |
| **Network namespace** | Isolamento Linux que permite ao container possuir o seu próprio contexto de interfaces, rotas e sockets. |
| **Port publishing** | Associação entre uma porta/endereço no host e uma porta no container. |
| **Registry** | Serviço de armazenamento e distribuição de imagens. |
| **Repository** | Coleção lógica de imagens/referências dentro de um registry. |
| **Service Compose** | Definição declarativa de um componente de uma aplicação Compose. |
| **Tag** | Referência legível associada a uma imagem, como `16` em `postgres:16`. |
| **User-defined bridge** | Bridge network criada explicitamente pelo utilizador, com isolamento/configuração própria e resolução automática de nomes. |
| **Writable layer** | Layer gravável específica de um container, associada ao seu lifecycle. |

---

# 29. Recursos e leituras complementares

## Livros de referência

### Docker Deep Dive

Nigel Poulton.  
Edição de maio de 2025.

Temas particularmente relevantes:

- Docker Engine;
- containers;
- networking;
- volumes;
- Compose;
- segurança.

### The Ultimate Docker Container Book

Dr. Gabriel N. Schenker.  
Fourth Edition, Packt Publishing, 2026.

Temas particularmente relevantes:

- ciclo de vida de containers;
- logs;
- inspeção;
- volumes;
- single-host networking;
- Docker Compose;
- troubleshooting.

## Documentação oficial

Docker Documentation:

```text
https://docs.docker.com/
```

Networking:

```text
https://docs.docker.com/engine/network/
```

Bridge networks:

```text
https://docs.docker.com/engine/network/drivers/bridge/
```

Storage:

```text
https://docs.docker.com/engine/storage/
```

Volumes:

```text
https://docs.docker.com/engine/storage/volumes/
```

Bind mounts:

```text
https://docs.docker.com/engine/storage/bind-mounts/
```

Docker Compose:

```text
https://docs.docker.com/compose/
```

Compose file reference:

```text
https://docs.docker.com/reference/compose-file/
```

Compose CLI:

```text
https://docs.docker.com/reference/cli/docker/compose/
```

> As ferramentas de containers evoluem regularmente. Para opções, defaults e comportamentos dependentes de versão, a documentação oficial deve ser considerada a referência operacional primária.
