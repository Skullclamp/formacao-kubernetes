# Lab 5 — Symfony Demo + PostgreSQL com Docker Compose

**Sessão:** 2  
**Duração prevista:** 40 minutos  
**Nível:** intermédio  
**Objetivo:** interpretar, validar e operar uma aplicação multi-container com Docker Compose, compreendendo serviços, rede, variáveis, dependências e persistência.

A progressão deste laboratório é:

```text
LER
  ↓
VALIDAR
  ↓
EXECUTAR
  ↓
OBSERVAR
  ↓
PROVAR PERSISTÊNCIA
  ↓
EXPLICAR
```

> Nesta sessão consumimos uma imagem da aplicação já existente. **Não usamos `docker build`**; a construção de imagens é trabalhada na Sessão 3.

---

# 0. Arquitetura do cenário

```text
Utilizador :8080
      ↓
Symfony Demo
PHP 8.4 + Apache
      ↓
 app-network
      ↓
PostgreSQL 16
      ↓
   db-data
```

Duas ideias devem ficar claras antes de executar:

```text
app → comunica com db pelo nome do serviço na rede Compose

db-data → preserva os dados fora do ciclo de vida do container PostgreSQL
```

---

# CP1 — Preparar a configuração do laboratório

## Objetivo

Criar a configuração local a partir do exemplo sem alterar o ficheiro modelo versionado no Git.

## O que estamos a fazer e porquê

O `README.md` da sessão deixa o terminal em `formacao-kubernetes/sessao-02`. A partir dessa diretoria entramos em `compose/`, onde se encontram `compose.yaml` e `.env.example`.

```bash
cd compose
cp .env.example .env
```

### Explicação

- `cd compose` entra na diretoria de configuração Compose da Sessão 2;
- `cp ORIGEM DESTINO` cria a configuração local sem destruir o exemplo distribuído aos formandos.

Confirme a localização:

```bash
pwd
ls -la
```

Rever:

```bash
cat .env
```

Substitua a referência de imagem indicada no ficheiro pelo valor fornecido pelo formador quando necessário.

> Os valores deste laboratório são didáticos. Um ficheiro `.env` é uma conveniência de configuração; **não é um secret manager**.

### CHECKPOINT CP1

```text
estamos em formacao-kubernetes/sessao-02/compose
.env existe
imagem da aplicação está definida
```

**Evidência:** mostrar apenas variáveis não sensíveis necessárias ao exercício; não copiar passwords reais para evidências.

---

# CP2 — Ler o `compose.yaml` antes de o executar

## Objetivo

Interpretar a definição declarativa da stack e antecipar que recursos serão criados.

## O que estamos a fazer e porquê

Compose substitui uma sequência longa de `docker run`, `docker network create` e `docker volume create` por uma definição declarativa reproduzível.

Abra o ficheiro:

```bash
less compose.yaml
```

Identifique:

1. serviços `app` e `db`;
2. imagem de cada serviço;
3. publicação `HOST:CONTAINER` da aplicação;
4. variáveis de ambiente;
5. `depends_on`;
6. rede `app-network`;
7. volume `db-data`;
8. healthcheck do PostgreSQL.

### Porque `DATABASE_URL` usa `db:5432` e não `localhost:5432`?

Dentro do container `app`, `localhost` significa **o próprio container da aplicação**. O serviço PostgreSQL vive noutro container. Na rede Compose, o nome do serviço `db` é resolvido internamente para o container da base de dados.

```text
app container
localhost → app container

db → serviço PostgreSQL através do DNS da rede Compose
```

### Sobre `depends_on`

Neste laboratório, a aplicação depende de:

```yaml
condition: service_healthy
```

Isto faz Compose aguardar que o healthcheck do PostgreSQL reporte `healthy` antes de iniciar a dependência `app` no fluxo de `up`. Ainda assim, aplicações reais devem ser tolerantes a indisponibilidade temporária e implementar retry/reconexão quando adequado.

### CHECKPOINT CP2

O formando consegue explicar, antes de executar:

```text
2 serviços
1 rede
1 volume
1 porta publicada
healthcheck da DB
app encontra DB pelo nome db
```

---

# CP3 — Renderizar e validar a configuração final

## Objetivo

Detetar erros de sintaxe, variáveis em falta e perceber o resultado efetivo depois da interpolação.

```bash
docker compose config
```

### Explicação

`docker compose config` não inicia containers. O comando:

- lê os ficheiros Compose;
- aplica variáveis de ambiente e defaults;
- valida a estrutura;
- apresenta a configuração efetiva.

Isto é um **gate**: não avançar para `up` enquanto houver erro de configuração.

Pode confirmar apenas os serviços reconhecidos:

```bash
docker compose config --services
```

Esperado:

```text
app
db
```

### CHECKPOINT CP3

```text
config termina sem erro
serviços app e db reconhecidos
variáveis interpoladas como esperado
```

**Evidência:** guardar `docker compose config --services` e qualquer trecho relevante da configuração final, sem expor credenciais.

---

# CP4 — Iniciar a stack e observar a convergência

## Objetivo

Criar os recursos declarados e verificar o estado dos dois serviços.

```bash
docker compose up -d
```

### Flags

- `up` cria/recria os recursos necessários e inicia os serviços;
- `-d` executa a stack em background, devolvendo o terminal ao operador.

Observar:

```bash
docker compose ps
docker compose logs db
docker compose logs app
```

### Explicação

- `docker compose ps` mostra o estado dos containers que pertencem ao projeto atual;
- `docker compose logs SERVIÇO` agrega os logs do serviço indicado;
- começamos por `db` porque a aplicação depende da base de dados.

Se quiser acompanhar a inicialização:

```bash
docker compose logs -f db
```

`-f` mantém o acompanhamento em tempo real. Termine com `Ctrl+C` quando a base estiver pronta.

### O que observar

Procure no `ps`:

```text
db  → Up / healthy
app → Up
```

Se `app` falhar, não execute repetidamente `up`. Leia primeiro `docker compose logs app` e o estado de `db`.

### CHECKPOINT CP4

```text
PostgreSQL healthy
aplicação em execução
rede e volume criados pelo projeto
```

---

# CP5 — Inicializar a base de dados apenas quando necessário

## Objetivo

Preparar o schema numa base vazia sem transformar uma operação de inicialização num comando repetido indiscriminadamente.

O formador indicará se a imagem e a base já contêm o estado necessário.

Quando for necessário criar o schema:

```bash
docker compose exec app \
  php bin/console doctrine:schema:create \
  --no-interaction
```

### Explicação

- `docker compose exec app` executa o comando num container **já em execução** do serviço `app`;
- `php bin/console` executa a CLI Symfony;
- `doctrine:schema:create` cria o schema numa base vazia;
- `--no-interaction` evita perguntas interativas, tornando o passo reproduzível.

Se a imagem disponibilizar fixtures e o formador indicar a sua utilização:

```bash
docker compose exec app \
  php bin/console doctrine:fixtures:load \
  --no-interaction
```

> Não volte a carregar fixtures durante a prova de persistência, porque isso poderia recriar dados e produzir uma conclusão errada.

---

# CP6 — Validar saúde, prontidão e identidade da aplicação

## Objetivo

Confirmar que processo a correr, aplicação saudável e aplicação pronta não são conceitos equivalentes.

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

### O que cada endpoint demonstra

```text
/health → saúde básica da aplicação
/ready  → capacidade para servir pedidos que dependem da DB
/info   → versão/ambiente/identidade pedagógica
```

- `curl -i` inclui os cabeçalhos HTTP e facilita confirmar o código de resposta;
- um `/health` bem-sucedido não prova, por si só, que PostgreSQL está acessível.

### CHECKPOINT CP6

```text
/health OK
/ready OK
/info devolve versão/ambiente esperado
```

**Evidência:** guardar código HTTP e campos relevantes dos endpoints.

---

# CP7 — Inspecionar os recursos criados por Compose

## Objetivo

Relacionar o YAML declarado com os objetos efetivamente criados pelo Docker.

```bash
docker compose ps
docker network ls
docker volume ls
```

Localize a rede e o volume associados ao projeto. O nome físico pode incluir o nome do projeto como prefixo.

Para obter os nomes diretamente através de Compose:

```bash
docker compose config --services
docker compose ps -q db
docker compose ps -q app
```

- `-q` (*quiet*) devolve apenas o ID do container do serviço.

Inspecionar mounts da base de dados:

```bash
DB_CID=$(docker compose ps -q db)
docker inspect "$DB_CID" \
  --format '{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{"\n"}}{{end}}'
```

Esperado: um volume montado em `/var/lib/postgresql/data`.

### CHECKPOINT CP7

O formando consegue mapear:

```text
compose.yaml service → container
network declaration  → rede Docker
volume declaration   → named volume
ports                 → publicação no host
```

---

# CP8 — Provar persistência após recriação dos containers

## Objetivo

Demonstrar, com um marcador determinístico, que os dados PostgreSQL não dependem da existência de uma instância concreta do container `db`.

## O que estamos a fazer e porquê

Em vez de depender de uma operação manual na interface da aplicação, criamos um pequeno marcador diretamente na base de dados. O objetivo deste checkpoint é testar o **named volume**, não a funcionalidade de edição da Symfony Demo.

Criar uma tabela de laboratório e um valor conhecido, reutilizando as variáveis efetivas do próprio container PostgreSQL:

```bash
docker compose exec -T db \
  sh -ec 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<"SQL"
CREATE TABLE IF NOT EXISTS lab_marker (
  id integer PRIMARY KEY,
  note text NOT NULL
);
INSERT INTO lab_marker (id, note)
VALUES (1, '\''sessao2-persistencia-ok'\'')
ON CONFLICT (id) DO UPDATE SET note = EXCLUDED.note;
SELECT id, note FROM lab_marker WHERE id = 1;
SQL'
```

Esperado:

```text
1 | sessao2-persistencia-ok
```

> O valor é escrito **antes** de remover os containers. Depois do `down`, não voltamos a executar o `INSERT`; apenas consultamos o que já estava armazenado.

Parar e remover os containers do projeto, preservando os volumes:

```bash
docker compose down
```

### O que faz `down`?

Remove os containers e a rede criada pelo projeto. Por omissão, o named volume declarado **não é removido**.

Confirmar que o volume continua disponível:

```bash
docker volume ls
```

Recriar a stack:

```bash
docker compose up -d
docker compose ps
curl -i http://localhost:8080/ready
```

Agora **apenas consultar** o marcador, sem o recriar:

```bash
docker compose exec -T db \
  sh -ec 'exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, note FROM lab_marker WHERE id = 1;"'
```

Esperado novamente:

```text
1 | sessao2-persistencia-ok
```

### Porque esta prova evita um falso positivo?

```text
antes do down  → escrever marcador
        ↓
down           → containers removidos
        ↓
volume         → permanece
        ↓
up             → novos containers
        ↓
depois do up   → apenas SELECT
```

Se o segundo `SELECT` encontra o mesmo valor, a evidência vem do volume persistente e não de um comando de inicialização que tenha recriado o marcador.

### Atenção: não usar `-v` nesta prova

```bash
docker compose down -v
```

`-v` pede a remoção dos volumes declarados pelo projeto. Usá-lo destruiria precisamente o objeto de persistência que estamos a testar.

### CHECKPOINT CP8

```text
marcador criado antes do down
containers antigos removidos
named volume permaneceu
a stack foi recriada
/ready voltou a OK
SELECT posterior devolveu o mesmo marcador sem o recriar
```

**Evidência:** guardar o resultado do `SELECT` antes e depois da recriação.

---

# CP9 — Fecho e regra de evidência

O laboratório fica concluído quando o formando consegue explicar e provar:

```text
compose.yaml validado antes de executar
+
app e db criados como serviços separados
+
app encontra db pelo DNS da rede Compose
+
PostgreSQL possui healthcheck
+
/health ≠ /ready
+
named volume montado na DB
+
marcador escrito antes do down
+
containers recriados
+
mesmo marcador lido depois do up sem novo INSERT
+
Compose single-host ≠ orquestração de Alta Disponibilidade
```

Para terminar a sessão mantendo os dados disponíveis para o laboratório de troubleshooting, deixe a stack operacional salvo indicação contrária do formador.
