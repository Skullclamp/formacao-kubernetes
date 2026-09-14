# Lab 6 — Troubleshooting Integrado

**Sessão:** 2  
**Duração prevista:** 40 minutos  
**Nível:** intermédio  
**Objetivo:** diagnosticar uma falha Docker/Compose através de evidências antes de efetuar alterações.

Este laboratório não avalia a rapidez com que se “tenta coisas”. Avalia a capacidade de construir um diagnóstico explicável.

```text
SINTOMA
   ↓
ESTADO
   ↓
LOGS
   ↓
CONFIGURAÇÃO
   ↓
REDE / PORTAS / MOUNTS
   ↓
HIPÓTESE
   ↓
TESTE DA HIPÓTESE
   ↓
CORREÇÃO
   ↓
VALIDAÇÃO
```

> A correção só deve ser aplicada depois de existir uma hipótese suportada por evidência.

---

# CP0 — Confirmar a diretoria do projeto Compose

Todos os comandos `docker compose` deste laboratório dependem do `compose.yaml` e do `.env` preparados no Lab 5. Se abriu uma nova shell, volte explicitamente à diretoria correta:

```bash
cd "$HOME/formacao-kubernetes/sessao-02/compose"
pwd
test -f compose.yaml && echo 'OK: compose.yaml disponível'
test -f .env && echo 'OK: .env disponível'
```

Esperado:

```text
.../formacao-kubernetes/sessao-02/compose
OK: compose.yaml disponível
OK: .env disponível
```

**Não avançar** se o ficheiro `.env` não existir: volte ao Lab 5 e copie `.env.example` para `.env` antes de continuar.

---

# CP1 — Criar uma baseline saudável

## Objetivo

Provar que a stack funciona antes de o incidente ser introduzido.

## O que estamos a fazer e porquê

Se não registarmos um estado de referência, uma falha anterior ao exercício pode ser atribuída incorretamente ao incidente controlado.

```bash
docker compose ps
curl -i http://localhost:8080/info
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
```

### Explicação

- `docker compose ps` mostra o estado dos serviços do projeto atual;
- `curl -i` inclui o código/cabeçalhos HTTP na resposta;
- `/info` ajuda a identificar a versão e o ambiente;
- `/health` testa saúde básica;
- `/ready` testa a prontidão incluindo a dependência da base de dados.

### Evidência mínima

```text
app em execução
db em execução/healthy
/health → sucesso
/ready  → sucesso
/info   → versão esperada
```

### CHECKPOINT CP1

**Não iniciar o incidente** enquanto a baseline não estiver saudável.

---

# CP2 — Receber o incidente sem conhecer a causa

## Objetivo

Trabalhar a partir do sintoma, como num cenário real de operação.

O formador introduzirá **uma falha controlada** no ambiente. A causa não será indicada.

Antes de executar qualquer correção, registe:

```text
Sintoma observado:
Hora aproximada:
Serviço afetado:
Último estado conhecido como bom:
```

> Não execute de imediato `docker compose down`, `docker rm -f`, reinstalações ou alterações aleatórias. Estes comandos podem destruir precisamente a evidência necessária para compreender o problema.

---

# CP3 — Classificar o estado dos serviços

## Objetivo

Responder primeiro à pergunta: **o serviço existe e está em execução?**

```bash
docker compose ps
docker compose ps -a
```

### Explicação

- `docker compose ps` mostra os containers em execução associados à stack;
- `-a` inclui também containers parados quando aplicável.

Para obter IDs sem perder containers que possam estar em `Exited`:

```bash
docker compose ps -a -q app
docker compose ps -a -q db
```

- `-a` inclui containers parados;
- `-q` devolve apenas o ID, útil para passar o objeto a `docker inspect`.

### O que observar

Distinga pelo menos:

```text
container inexistente
container Exited
container Up
container healthy/unhealthy
```

Um container `Up` não prova que a aplicação está operacional.

### CHECKPOINT CP3

Registe o estado exato de `app` e `db` antes de continuar.

---

# CP4 — Ler os logs antes de alterar a configuração

## Objetivo

Procurar erros ou alterações de comportamento emitidos pela aplicação e pela base de dados.

```bash
docker compose logs --tail 100 app
docker compose logs --tail 100 db
```

### Flags

- `--tail 100` limita a análise às 100 linhas mais recentes de cada serviço;
- indicar `app` ou `db` evita misturar inicialmente fontes diferentes.

Se o problema estiver a acontecer neste momento:

```bash
docker compose logs -f app
```

- `-f` acompanha novas linhas em tempo real;
- `Ctrl+C` termina apenas a visualização, não o serviço.

### O que observar

Procure mensagens relacionadas com:

```text
bind de porta
ligação à base de dados
resolução de nome
credenciais/configuração
ficheiros/mounts
processo terminado
```

Não conclua a causa apenas por uma linha isolada. Relacione a mensagem com o sintoma e o estado observado no CP3.

---

# CP5 — Inspecionar configuração efetiva

## Objetivo

Comparar aquilo que pensamos ter configurado com aquilo que o Docker efetivamente está a executar.

Primeiro renderize Compose:

```bash
docker compose config
```

Depois obtenha os IDs, incluindo containers parados:

```bash
APP_CID=$(docker compose ps -a -q app)
DB_CID=$(docker compose ps -a -q db)

printf 'APP_CID=%s\n' "$APP_CID"
printf 'DB_CID=%s\n' "$DB_CID"
```

Se um ID estiver vazio, isso é já uma evidência: o objeto container correspondente não existe e não deve ser passado a `docker inspect`.

Quando o ID existir, inspecionar:

```bash
[ -n "$APP_CID" ] && docker inspect "$APP_CID"
[ -n "$DB_CID" ] && docker inspect "$DB_CID"
```

Extrair informação específica da aplicação, apenas se `APP_CID` existir:

```bash
if [ -n "$APP_CID" ]; then
  docker inspect "$APP_CID" \
    --format 'Status={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}'

  docker inspect "$APP_CID" \
    --format '{{range .Config.Env}}{{println .}}{{end}}'

  docker inspect "$APP_CID" \
    --format '{{json .NetworkSettings.Ports}}'
fi
```

### Porque usamos `--format`?

`docker inspect` devolve muita informação. `--format` permite selecionar os campos relevantes para testar uma hipótese sem procurar manualmente em todo o JSON.

> Ao recolher evidência, evite copiar para relatórios valores sensíveis provenientes de `.Config.Env`.

### CHECKPOINT CP5

O formando consegue indicar, quando o objeto existe:

```text
estado efetivo
health quando existente
imagem
variáveis relevantes
portas
mounts
redes
```

Se o objeto não existir, consegue explicar que **ausência do container** é a evidência relevante e não um erro do `docker inspect`.

---

# CP6 — Validar rede, nomes e dependências

## Objetivo

Distinguir uma aplicação indisponível por problema de processo de uma aplicação que não consegue chegar à dependência.

Listar redes:

```bash
docker network ls
```

Descobrir as redes dos containers que existam:

```bash
if [ -n "$APP_CID" ]; then
  docker inspect "$APP_CID" \
    --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} {{"\n"}}{{end}}'
fi

if [ -n "$DB_CID" ]; then
  docker inspect "$DB_CID" \
    --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} {{"\n"}}{{end}}'
fi
```

Quando ambos existem, os dois serviços devem partilhar a rede prevista no Compose.

Testar a partir da aplicação **apenas quando o serviço `app` está em execução**:

```bash
docker compose exec app getent hosts db
```

### Explicação

- `docker compose exec app` executa o comando dentro do serviço `app`;
- `getent hosts db` pede ao resolver do container para localizar o nome `db`;
- sucesso demonstra resolução de nome, mas não garante que PostgreSQL aceite ligações.

Consultar o health da DB quando `DB_CID` existir:

```bash
if [ -n "$DB_CID" ]; then
  docker inspect "$DB_CID" \
    --format '{{if .State.Health}}{{json .State.Health}}{{else}}sem-healthcheck{{end}}'
fi
```

### Camadas a distinguir

```text
container app/db não existe
→ ciclo de vida / criação Compose

nome db não resolve
→ rede/DNS interno/configuração de rede

nome resolve, DB unhealthy
→ serviço PostgreSQL/healthcheck/configuração

DB healthy, /ready falha
→ aplicação/credenciais/DATABASE_URL/outra dependência
```

---

# CP7 — Testar portas e mounts apenas quando relevantes para a hipótese

Portas da aplicação, quando `APP_CID` existir:

```bash
[ -n "$APP_CID" ] && docker port "$APP_CID"
```

Mounts da DB, quando `DB_CID` existir:

```bash
if [ -n "$DB_CID" ]; then
  docker inspect "$DB_CID" \
    --format '{{range .Mounts}}{{.Type}} {{.Name}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
fi
```

### O que observar

- se `docker port` não mostra a publicação esperada, o problema pode estar na configuração Compose;
- se o volume PostgreSQL não está montado em `/var/lib/postgresql/data`, a persistência/configuração deve ser investigada;
- não altere rede, porta e volume ao mesmo tempo. Mude **uma variável de cada vez** para saber o que resolveu o incidente.

---

# CP8 — Formular e validar uma hipótese

Antes da correção, preencha a ficha [`../desafios/troubleshooting.md`](../desafios/troubleshooting.md) com:

- sintoma;
- primeira evidência;
- estado dos serviços;
- logs relevantes;
- configuração relevante;
- hipótese;
- comando/teste que confirma ou rejeita a hipótese;
- causa raiz proposta.

Formato recomendado:

```text
EVIDÊNCIA
   ↓
HIPÓTESE
   ↓
PREVISÃO: se a hipótese for verdadeira, devo observar X
   ↓
TESTE
   ↓
CONFIRMAR ou REJEITAR
```

### CHECKPOINT CP8

Não corrigir enquanto não conseguir responder:

> Que evidência concreta torna esta hipótese mais provável do que as alternativas?

---

# CP9 — Aplicar a correção mínima e validar recuperação

Depois de a causa estar sustentada, efetue apenas a alteração necessária.

Validação final obrigatória:

```bash
docker compose ps
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

Reveja também os logs depois da correção:

```bash
docker compose logs --tail 30 app
docker compose logs --tail 30 db
```

### Porque validamos todos estes pontos?

Uma alteração pode fazer o processo arrancar sem resolver a funcionalidade que depende da DB. Queremos provar **recuperação do serviço**, não apenas ausência de um erro anterior.

### CHECKPOINT CP9

```text
containers no estado esperado
/health OK
/ready OK
/info correto
sem erro persistente relevante nos logs
```

**Evidência:** guardar resultados finais e compará-los com a baseline do CP1.

---

# CP10 — Explicação final do incidente

O formando deve conseguir explicar, por esta ordem:

1. qual era o sintoma;
2. que evidência recolheu primeiro;
3. em que camada classificou a falha;
4. qual foi a hipótese;
5. como a validou;
6. qual era a causa raiz;
7. que alteração mínima efetuou;
8. como provou a recuperação.

## Questão de consolidação

> A aplicação estar com `/health` funcional garante obrigatoriamente que está pronta para servir pedidos que necessitam da base de dados?

Não. Neste cenário, `/health` representa saúde básica da aplicação, enquanto `/ready` inclui a dependência PostgreSQL. A evidência correta para prontidão é observar ambos segundo a finalidade de cada endpoint.

## Regra de evidência da Sessão 2

```text
não corrigir por tentativa
        ↓
observar estado
        ↓
ler logs
        ↓
inspecionar configuração
        ↓
validar rede/portas/mounts conforme a hipótese
        ↓
provar causa
        ↓
corrigir o mínimo
        ↓
provar recuperação
```
