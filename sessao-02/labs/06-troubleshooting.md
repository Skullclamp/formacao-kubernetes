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

- `docker compose ps` mostra os containers associados à stack;
- `-a` inclui também containers parados quando aplicável.

Para obter apenas IDs:

```bash
docker compose ps -q app
docker compose ps -q db
```

- `-q` devolve apenas o ID, útil para passar o container a `docker inspect`.

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

Depois obtenha os IDs:

```bash
APP_CID=$(docker compose ps -q app)
DB_CID=$(docker compose ps -q db)
```

Inspecionar:

```bash
docker inspect "$APP_CID"
docker inspect "$DB_CID"
```

Extrair informação específica da aplicação:

```bash
docker inspect "$APP_CID" \
  --format 'Status={{.State.Status}} Health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}'

docker inspect "$APP_CID" \
  --format '{{range .Config.Env}}{{println .}}{{end}}'

docker inspect "$APP_CID" \
  --format '{{json .NetworkSettings.Ports}}'
```

### Porque usamos `--format`?

`docker inspect` devolve muita informação. `--format` permite selecionar os campos relevantes para testar uma hipótese sem procurar manualmente em todo o JSON.

> Ao recolher evidência, evite copiar para relatórios valores sensíveis provenientes de `.Config.Env`.

### CHECKPOINT CP5

O formando consegue indicar:

```text
estado efetivo
health quando existente
imagem
variáveis relevantes
portas
mounts
redes
```

---

# CP6 — Validar rede, nomes e dependências

## Objetivo

Distinguir uma aplicação indisponível por problema de processo de uma aplicação que não consegue chegar à dependência.

Listar redes:

```bash
docker network ls
```

Descobrir as redes da aplicação:

```bash
docker inspect "$APP_CID" \
  --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} {{"\n"}}{{end}}'

docker inspect "$DB_CID" \
  --format '{{range $name, $cfg := .NetworkSettings.Networks}}{{$name}} {{"\n"}}{{end}}'
```

Os dois serviços devem partilhar a rede prevista no Compose.

Testar a partir da aplicação quando o container está operacional:

```bash
docker compose exec app getent hosts db
```

### Explicação

- `docker compose exec app` executa o comando dentro do serviço `app`;
- `getent hosts db` pede ao resolver do container para localizar o nome `db`;
- sucesso demonstra resolução de nome, mas não garante que PostgreSQL aceite ligações.

Consultar o health da DB:

```bash
docker inspect "$DB_CID" \
  --format '{{if .State.Health}}{{json .State.Health}}{{else}}sem-healthcheck{{end}}'
```

### Camadas a distinguir

```text
nome db não resolve
→ rede/DNS interno/configuração de rede

nome resolve, DB unhealthy
→ serviço PostgreSQL/healthcheck/configuração

DB healthy, /ready falha
→ aplicação/credenciais/DATABASE_URL/outra dependência
```

---

# CP7 — Testar portas e mounts apenas quando relevantes para a hipótese

Portas da aplicação:

```bash
docker port "$APP_CID"
```

Mounts da DB:

```bash
docker inspect "$DB_CID" \
  --format '{{range .Mounts}}{{.Type}} {{.Name}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
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
