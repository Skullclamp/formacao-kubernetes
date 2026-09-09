# Manual do Formando
## Sessão 2 — Docker I: Operação, Networking, Storage e Docker Compose

## Identificação

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 2 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **N.º estimado de formandos** | Até 5 |
| **Foco pedagógico** | Operar containers e aplicações multi-container |
| **Cenário transversal** | Symfony Demo + PostgreSQL 16 |

---

# 1. Enquadramento

Na Sessão 1 foram trabalhados os fundamentos de containers e Kubernetes. Nesta sessão o objetivo é consolidar a operação de Docker antes de avançar para a construção e preparação de imagens na Sessão 3.

A palavra-chave desta sessão é:

```text
OPERAR
```

O percurso é:

```text
Imagem existente
      ↓
Container
      ↓
Estado / Logs / Inspect / Exec / Stats
      ↓
Networking
      ↓
Storage
      ↓
Docker Compose
      ↓
Symfony Demo + PostgreSQL
      ↓
Troubleshooting
```

Nesta sessão **não construímos a imagem Symfony**. Dockerfile, build, layers, cache, multi-stage, hardening, scan e publicação no registry serão trabalhados na Sessão 3.

---

# 2. Objetivos da Sessão

No final da sessão deverá ser capaz de:

1. Obter e identificar imagens num registry.
2. Criar, iniciar, parar, reiniciar e remover containers.
3. Publicar portas e validar o acesso à aplicação.
4. Consultar logs e acompanhar a execução de um container.
5. Utilizar `docker exec` para diagnóstico.
6. Utilizar `docker inspect` para consultar configuração e estado.
7. Consultar consumo de recursos com `docker stats`.
8. Criar e inspecionar redes Docker.
9. Compreender a resolução de nomes entre containers numa rede definida pelo utilizador.
10. Distinguir filesystem efémero, bind mount e named volume.
11. Validar persistência depois de recriar um container.
12. Distinguir persistência de backup.
13. Interpretar e utilizar um `compose.yaml`.
14. Operar uma stack multi-container com Docker Compose.
15. Aplicar uma sequência estruturada de troubleshooting.

---

# 3. Ambiente de Referência

A aplicação transversal utiliza:

- Symfony Demo `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16.

A imagem de referência da aplicação para esta sessão é:

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
```

A aplicação é utilizada como imagem já existente. O objetivo é observar e operar o seu comportamento.

No repositório de apoio, a Sessão 2 encontra-se em:

```text
sessao-02/
```

Os principais recursos são:

```text
sessao-02/
├── README.md
├── plano_sessao_2.md
├── manual_formando.md
├── checklist.md
├── compose/
│   ├── compose.yaml
│   └── .env.example
├── labs/
│   ├── 01-containers.md
│   ├── 02-diagnostico.md
│   ├── 03-networking.md
│   ├── 04-storage.md
│   ├── 05-compose.md
│   └── 06-troubleshooting.md
└── desafios/
    └── troubleshooting.md
```

---

# 4. Imagem e Container

## 4.1. Imagem

Uma imagem é um artefacto utilizado para criar containers.

```text
Imagem
  ↓
docker run
  ↓
Container
```

A imagem não é alterada quando um container é iniciado, parado ou removido.

### Obter uma imagem

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
```

### Consultar imagens

```bash
docker images
```

ou:

```bash
docker image ls
```

### Nome e tag

```text
ghcr.io/skullclamp/symfony-demo:1.0.0
│             │            │
registry      imagem       tag
```

Nesta formação privilegiamos referências versionadas em vez de depender de `latest`.

---

## 4.2. Container

Um container é uma instância em execução, ou parada, criada a partir de uma imagem.

### Executar

```bash
docker run --name web-demo -d -p 8080:80 \
  ghcr.io/skullclamp/symfony-demo:1.0.0
```

### Consultar containers em execução

```bash
docker ps
```

### Consultar todos os containers

```bash
docker ps -a
```

### Parar

```bash
docker stop web-demo
```

### Iniciar novamente

```bash
docker start web-demo
```

### Reiniciar

```bash
docker restart web-demo
```

### Remover

```bash
docker rm web-demo
```

Se o container ainda estiver em execução, deverá primeiro pará-lo ou utilizar conscientemente a opção de remoção forçada.

---

# 5. Portas

A aplicação pode escutar numa porta dentro do container sem estar diretamente acessível através dessa mesma porta no host.

```text
Host                         Container

localhost:8080  ---------->  porta 80
        │
        └── publicação através de -p 8080:80
```

O primeiro número representa a porta no host; o segundo representa a porta no container.

```bash
docker run -d --name web-demo \
  -p 8080:80 \
  ghcr.io/skullclamp/symfony-demo:1.0.0
```

Validar:

```bash
curl http://localhost:8080/
```

Consultar portas publicadas:

```bash
docker port web-demo
```

ou:

```bash
docker ps
```

## Erro frequente — porta ocupada

Se outro processo ou container já utilizar a porta `8080`, o novo container não conseguirá publicar essa porta.

Antes de alterar configurações, identifique o conflito.

```bash
docker ps
```

Quando necessário, no Linux:

```bash
ss -ltnp
```

---

# 6. Observar Antes de Alterar

Uma regra importante desta formação é:

> Antes de alterar configuração, recolha evidências.

A sequência de diagnóstico recomendada é:

```text
Estado
  ↓
Logs
  ↓
Inspect
  ↓
Exec, se necessário
  ↓
Recursos
  ↓
Hipótese
  ↓
Alteração
  ↓
Validação
```

---

# 7. Logs

Os logs são uma das primeiras fontes de evidência.

### Consultar logs

```bash
docker logs web-demo
```

### Acompanhar em tempo real

```bash
docker logs -f web-demo
```

### Limitar a saída

```bash
docker logs --tail 50 web-demo
```

### Adicionar timestamps

```bash
docker logs -t web-demo
```

Perguntas úteis ao analisar logs:

- A aplicação iniciou?
- Existe um erro de configuração?
- Existe uma falha de ligação à base de dados?
- Existe uma exceção?
- O processo terminou?

---

# 8. docker inspect

`docker inspect` apresenta informação detalhada sobre um objeto Docker.

```bash
docker inspect web-demo
```

Entre outras informações, poderá encontrar:

- imagem utilizada;
- variáveis de ambiente;
- mounts;
- configuração de rede;
- portas;
- estado;
- política de restart;
- limites de recursos.

### Consultar apenas a imagem

```bash
docker inspect web-demo \
  --format '{{.Config.Image}}'
```

### Consultar endereço IP

```bash
docker inspect web-demo \
  --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
```

### Consultar mounts

```bash
docker inspect web-demo \
  --format '{{json .Mounts}}'
```

---

# 9. docker exec

`docker exec` permite executar um processo adicional dentro de um container que já está em execução.

```bash
docker exec -it web-demo sh
```

Pode ser útil para:

- verificar ficheiros;
- consultar variáveis;
- testar resolução DNS;
- confirmar processos;
- executar um comando de diagnóstico.

No entanto:

> `docker exec` é uma ferramenta de diagnóstico, não uma estratégia normal para configurar manualmente aplicações em produção.

Alterações feitas manualmente dentro de um container podem desaparecer quando esse container for substituído.

---

# 10. docker stats

Para observar consumo de recursos:

```bash
docker stats
```

Uma observação pontual:

```bash
docker stats --no-stream
```

Informação típica:

- CPU;
- memória;
- tráfego de rede;
- I/O;
- processos.

A existência de consumo elevado não indica automaticamente a causa de um problema, mas constitui evidência útil.

---

# 11. Networking Docker

## 11.1. Porque precisamos de redes?

Uma aplicação raramente funciona isolada.

```text
Aplicação Web
     │
     │ rede Docker
     ▼
PostgreSQL
```

O objetivo é permitir comunicação controlada entre containers.

---

## 11.2. Consultar redes

```bash
docker network ls
```

A rede `bridge` existe por omissão.

---

## 11.3. Criar uma rede

```bash
docker network create app-network
```

Consultar:

```bash
docker network inspect app-network
```

---

## 11.4. Resolução por nome

Em redes definidas pelo utilizador, os containers podem resolver outros containers pelo nome.

Exemplo conceptual:

```text
container: app
    │
    │ liga a
    ▼
hostname: db
    │
    ▼
container PostgreSQL
```

A aplicação pode utilizar:

```text
db:5432
```

em vez de depender do endereço IP atual do container PostgreSQL.

O IP pode mudar; o nome lógico do serviço deverá permanecer estável dentro da rede.

---

## 11.5. Porta interna vs. porta publicada

A base de dados pode comunicar com a aplicação através da rede Docker sem que a porta `5432` seja publicada no host.

```text
Aplicação ───────> db:5432

Host
  X não necessita necessariamente de 5432 publicada
```

Isto reduz exposição desnecessária.

---

# 12. Storage em Containers

## 12.1. Filesystem gravável do container

Um container possui uma layer gravável durante a sua existência.

```text
Imagem
  ↓
Container
  ↓
Layer gravável
```

Se dados importantes forem armazenados apenas nessa layer e o container for removido, esses dados deixam de estar associados ao novo container.

---

## 12.2. Bind Mount

Um bind mount liga diretamente um caminho do host a um caminho no container.

```text
Host
/home/user/dados
      │
      ▼
Container
/app/dados
```

Exemplo:

```bash
docker run --rm \
  -v "$PWD/dados:/dados" \
  alpine:3.20 \
  ls -la /dados
```

O bind mount depende explicitamente de um caminho do host.

---

## 12.3. Named Volume

Um named volume é gerido pelo Docker.

Criar:

```bash
docker volume create dados-demo
```

Consultar:

```bash
docker volume ls
```

Inspecionar:

```bash
docker volume inspect dados-demo
```

Utilizar:

```bash
docker run --rm \
  -v dados-demo:/dados \
  alpine:3.20 \
  sh -c 'echo teste > /dados/ficheiro.txt'
```

Confirmar posteriormente:

```bash
docker run --rm \
  -v dados-demo:/dados \
  alpine:3.20 \
  cat /dados/ficheiro.txt
```

A persistência é independente do container que escreveu o ficheiro.

---

## 12.4. Persistência não é Backup

```text
Volume persistente
        ≠
      Backup
```

Um volume protege os dados do ciclo de vida do container, mas não protege necessariamente contra:

- eliminação acidental do volume;
- corrupção lógica;
- erro humano;
- falha do armazenamento;
- ransomware;
- alterações destrutivas na aplicação.

Backup e recuperação serão trabalhados em maior profundidade noutras sessões.

---

# 13. Docker Compose

## 13.1. Problema que resolve

Sem Compose, uma aplicação multi-container pode exigir muitos comandos manuais.

```text
docker network create ...
docker volume create ...
docker run postgres ...
docker run app ...
```

Docker Compose permite definir o conjunto de serviços de forma declarativa.

```text
compose.yaml
    │
    ├── app
    ├── db
    ├── network
    └── volume
```

---

## 13.2. Estrutura do cenário da Sessão 2

O `compose.yaml` utiliza dois serviços principais:

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
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-network
```

A configuração completa encontra-se em:

```text
sessao-02/compose/compose.yaml
```

---

## 13.3. Variáveis

Antes do laboratório:

```bash
cd sessao-02/compose
cp .env.example .env
```

O `.env` inclui parâmetros como:

```text
SYMFONY_IMAGE
ghcr.io/skullclamp/symfony-demo:1.0.0

APP_PORT
APP_ENV
APP_VERSION
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
DATABASE_URL
```

O ficheiro `.env` facilita parametrização, mas não deverá ser interpretado como secret manager.

---

## 13.4. Validar configuração

Antes de iniciar:

```bash
docker compose config
```

Este comando é especialmente útil para:

- validar YAML;
- observar variáveis resolvidas;
- confirmar serviços;
- confirmar volumes e redes.

---

## 13.5. Iniciar

```bash
docker compose up -d
```

---

## 13.6. Consultar estado

```bash
docker compose ps
```

---

## 13.7. Logs

```bash
docker compose logs
```

Apenas aplicação:

```bash
docker compose logs app
```

Acompanhar:

```bash
docker compose logs -f app
```

---

## 13.8. Executar comandos num serviço

```bash
docker compose exec app sh
```

ou, na base de dados:

```bash
docker compose exec db psql -U symfony -d symfony
```

---

## 13.9. Parar e remover a stack

```bash
docker compose down
```

Por omissão, o named volume declarado não deve ser removido apenas porque os containers são removidos.

A opção:

```bash
docker compose down -v
```

remove também volumes associados. Deve ser utilizada conscientemente porque implica perda dos dados armazenados nesses volumes.

---

# 14. depends_on e Readiness

No cenário da sessão, a aplicação depende da base de dados.

```yaml
depends_on:
  db:
    condition: service_healthy
```

O PostgreSQL tem um healthcheck com `pg_isready`.

Isto permite ao Compose aguardar uma condição de saúde definida para a base de dados.

É importante perceber que:

```text
container iniciado
      ≠
serviço pronto
```

A ideia de readiness será retomada mais tarde no contexto de Kubernetes.

---

# 15. Laboratório Integrado

O laboratório final da Sessão 2 pretende que opere a stack Symfony + PostgreSQL.

## Sequência recomendada

```bash
cd sessao-02/compose
cp .env.example .env

docker compose config
docker compose up -d
docker compose ps
```

Consultar logs:

```bash
docker compose logs --tail 100 app
docker compose logs --tail 100 db
```

Consultar rede:

```bash
docker network ls
```

Consultar volumes:

```bash
docker volume ls
```

Consultar mounts do PostgreSQL:

```bash
DB_CID=$(docker compose ps -q db)
docker inspect "$DB_CID" --format '{{json .Mounts}}'
```

---

# 16. Troubleshooting Estruturado

Quando algo não funcionar, evite alterar várias coisas em simultâneo.

Utilize:

```text
1. Sintoma
2. Evidência
3. Hipótese
4. Teste
5. Correção
6. Validação
```

## Cenário A — container terminou

```bash
docker compose ps -a
docker compose logs app
```

Pergunte:

- qual foi o exit code?
- existe erro nos logs?
- a variável necessária existe?

## Cenário B — aplicação não acede à DB

Verifique:

```bash
docker compose ps
docker compose logs db
docker compose logs app
```

Depois confirme a rede:

```bash
docker network inspect <rede>
```

## Cenário C — dados desapareceram

Confirme primeiro:

- o serviço usava realmente um named volume?
- o volume foi removido?
- foi utilizado `docker compose down -v`?

## Cenário D — porta ocupada

Consulte containers existentes:

```bash
docker ps
```

Não altere a porta aleatoriamente sem identificar o processo que a utiliza.

---

# 17. Boas Práticas da Sessão

- Preferir tags explícitas em laboratórios versionados.
- Publicar apenas as portas realmente necessárias.
- Consultar logs antes de alterar configuração.
- Utilizar `docker inspect` como fonte de evidência.
- Evitar alterações manuais persistentes com `docker exec`.
- Utilizar redes definidas pelo utilizador para comunicação previsível por nome.
- Utilizar volumes para dados que não devem seguir o ciclo de vida do container.
- Não confundir volume com backup.
- Validar `docker compose config` antes de iniciar a stack.
- Não tratar `.env` como secret manager.

---

# 18. Resumo

```text
Imagem
  ↓
Container
  ↓
Ciclo de vida
  ↓
Logs / Inspect / Exec / Stats
  ↓
Networking
  ↓
Volumes
  ↓
Compose
  ↓
Aplicação multi-container
  ↓
Troubleshooting
```

As ideias mais importantes são:

```text
Imagem ≠ Container
Porta interna ≠ Porta publicada
Container ≠ Dados
Persistência ≠ Backup
Container iniciado ≠ Serviço pronto
Compose single-host ≠ Alta Disponibilidade
```

---

# 19. Exercícios de Consolidação

## Exercício 1 — Ciclo de vida

Explique o que acontece à imagem quando executa:

```bash
docker rm web-demo
```

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 2 — Portas

Interprete:

```bash
docker run -p 9090:80 nginx
```

Qual é a porta do host?

____________________________________________________________________

Qual é a porta do container?

____________________________________________________________________

## Exercício 3 — Diagnóstico

Ordene os passos:

```text
alterar configuração
consultar logs
identificar sintoma
validar resultado
formular hipótese
```

Resposta:

```text
1. __________________________________
2. __________________________________
3. __________________________________
4. __________________________________
5. __________________________________
```

## Exercício 4 — Storage

Explique a diferença entre:

- filesystem do container;
- bind mount;
- named volume.

Resposta:

____________________________________________________________________

____________________________________________________________________

____________________________________________________________________

## Exercício 5 — Persistência

Porque é que um named volume não deve ser confundido com um backup?

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 6 — Networking

Porque é preferível uma aplicação comunicar com o serviço `db` por nome numa rede Docker em vez de guardar o IP atual do container PostgreSQL?

Resposta:

____________________________________________________________________

____________________________________________________________________

## Exercício 7 — Compose

Indique a função de:

| Elemento | Função |
|---|---|
| `services` | ______________________________ |
| `image` | ______________________________ |
| `ports` | ______________________________ |
| `environment` | ______________________________ |
| `volumes` | ______________________________ |
| `networks` | ______________________________ |

---

# 20. Questões de Revisão

1. Qual é a diferença entre imagem e container?
2. Para que serve `docker ps -a`?
3. O que representa `8080:80` numa publicação de portas?
4. Qual é a diferença entre `docker logs` e `docker exec`?
5. Para que serve `docker inspect`?
6. Que informação fornece `docker stats`?
7. Qual é a vantagem de uma rede Docker definida pelo utilizador?
8. O que distingue um bind mount de um named volume?
9. Porque é que persistência não é sinónimo de backup?
10. Para que serve `docker compose config`?
11. Qual é a diferença entre `docker compose down` e `docker compose down -v`?
12. Porque é que um container iniciado pode ainda não estar pronto para receber pedidos?
13. Porque não devemos usar `docker exec` como método normal de configuração em produção?
14. Porque se evita depender de `latest` quando se pretende rastreabilidade?
15. Qual deve ser a primeira atitude quando ocorre uma falha: alterar ou recolher evidência?

---

# 21. Checklist de Competências

| Competência | Evidência esperada |
|---|---|
| Gerir containers | Cria, para, inicia, reinicia e remove |
| Consultar logs | Identifica informação relevante |
| Inspecionar container | Consulta imagem, mounts, rede e portas |
| Consultar recursos | Utiliza `docker stats` |
| Criar rede | Rede definida pelo utilizador disponível |
| Validar DNS interno | Comunicação por nome entre serviços |
| Criar volume | Named volume disponível |
| Validar persistência | Dados mantidos após recriação |
| Utilizar Compose | Stack iniciada e observada |
| Diagnosticar falha | Sequência de troubleshooting aplicada |

---

# 22. Transição para a Sessão 3

A Sessão 2 termina com a capacidade de **operar** uma aplicação existente.

A próxima questão é:

> Como transformamos o código da aplicação numa imagem reproduzível, otimizada, analisada, versionada e promovível entre ambientes?

```text
Sessão 2
OPERAR
   ↓
Sessão 3
CONSTRUIR / PREPARAR / PROMOVER
```
