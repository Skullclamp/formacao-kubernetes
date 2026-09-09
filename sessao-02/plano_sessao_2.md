# A) Plano de Formação — Sessão 2
## Docker I — Operação, Networking, Storage e Docker Compose

## 1. Identificação da sessão

| Elemento | Definição |
|---|---|
| **Formação** | Mini MBA em Orquestração de Containers com Kubernetes |
| **Sessão** | 2 |
| **Duração** | 4 horas / 240 minutos |
| **Nível** | Intermédio |
| **N.º estimado de formandos** | Até 5 |
| **Metodologia** | Expositiva e ativa, com forte componente prática |
| **Natureza da sessão** | Consolidação operacional de Docker antes da construção de imagens na Sessão 3 |
| **Cenário transversal** | Symfony Demo + PostgreSQL 16, executados a partir de imagens já disponibilizadas |
| **Progressão pedagógica** | Imagem existente → container → observação → rede → storage → Compose → troubleshooting |

A Sessão 2 é deliberadamente orientada para **OPERAR**. A construção de Dockerfiles, otimização de imagens, scan, registry e promoção ficam concentrados na Sessão 3.

---

## 2. Objetivos específicos

No final da sessão, os formandos deverão ser capazes de:

1. Obter e identificar imagens a partir de um registry.
2. Criar, iniciar, parar, reiniciar e remover containers.
3. Publicar portas e validar o acesso a um serviço containerizado.
4. Consultar logs e acompanhar a execução de uma aplicação.
5. Utilizar `docker exec` de forma consciente para troubleshooting.
6. Utilizar `docker inspect` para obter informação de configuração e estado.
7. Consultar consumo de recursos através de `docker stats`.
8. Compreender o funcionamento das redes bridge criadas pelo Docker.
9. Criar redes e utilizar resolução de nomes entre containers.
10. Distinguir filesystem efémero, bind mount e named volume.
11. Validar persistência de dados após recriação de containers.
12. Compreender a diferença entre persistência e backup.
13. Definir uma aplicação multi-container com Docker Compose.
14. Utilizar serviços, redes, volumes, variáveis e dependências em Compose.
15. Observar e diagnosticar problemas simples de execução, rede, portas, volumes e dependências.

---

## 3. Delimitação pedagógica

### Nesta sessão — OPERAR

- consumir imagens existentes;
- executar containers;
- gerir ciclo de vida;
- mapear portas;
- observar logs e estado;
- utilizar `exec`, `inspect` e `stats`;
- trabalhar networking Docker;
- trabalhar bind mounts e volumes;
- trabalhar Docker Compose;
- diagnosticar problemas operacionais simples.

### Fica para a Sessão 3 — CONSTRUIR E PREPARAR

- Dockerfile detalhado;
- build context e `.dockerignore`;
- layers e cache;
- multi-stage builds;
- hardening de imagem;
- `HEALTHCHECK` na imagem;
- scan de vulnerabilidades;
- tags, digests e promoção;
- publicação no registry;
- deployment/update/rollback de uma versão de produção single-host.

---

## 3.1. Revisão à luz das recomendações técnicas

A recomendação de introduzir **multi-stage builds** é pertinente para um público intermédio, mas, no desenho atual da formação, é aplicada na **Sessão 3**, não nesta sessão.

A separação fica:

```text
Sessão 2
OPERAR
→ imagens existentes
→ ciclo de vida
→ observação
→ networking
→ storage
→ Compose

Sessão 3
CONSTRUIR
→ Dockerfile
→ cache
→ multi-stage
→ hardening
→ scan
→ registry
```

Esta decisão evita misturar operação e construção e permite que multi-stage seja praticado efetivamente, em vez de surgir apenas como nota conceptual.

Nesta sessão, a segurança fica ao nível operacional essencial:

- não expor portas desnecessárias;
- não colocar credenciais diretamente em comandos ou ficheiros partilhados;
- observar mounts, variáveis e configuração antes de alterar o ambiente;
- usar versões explícitas das imagens de laboratório sempre que possível.

---

## 4. Cenário de referência

Será utilizada a aplicação **Symfony Demo** como caso transversal, acompanhada por **PostgreSQL 16**.

A Sessão 2 deverá começar por consumir imagens já existentes, permitindo concentrar a atenção na operação:

```text
Registry
   ↓
Imagem Symfony
   ↓
Container da aplicação
   │
   ├── porta publicada
   ├── logs / inspect / stats
   └── rede Docker
             │
             ▼
       PostgreSQL 16
             │
             ▼
        named volume
```

A evolução final da sessão será:

```text
containers isolados
       ↓
rede explícita
       ↓
storage persistente
       ↓
Docker Compose
       ↓
aplicação multi-container reproduzível
```

---

## 5. Conteúdos

### 5.1. Imagens e ciclo de vida de containers

- `docker pull`.
- `docker images`.
- Nome e tag da imagem como referência operacional.
- Preferência por versões explícitas no laboratório, evitando depender de `latest`.
- `docker run`.
- `docker ps` e `docker ps -a`.
- `docker stop`, `start`, `restart` e `rm`.
- Containers efémeros e persistentes.
- Port publishing: `-p HOST:CONTAINER`.

### 5.2. Observação e troubleshooting

- `docker logs` e `docker logs -f`.
- `docker exec`.
- `docker inspect`.
- `docker stats`.
- Estado do container.
- Processos, variáveis, mounts, network settings e portas.

### 5.3. Networking Docker

- Rede bridge por omissão.
- Redes definidas pelo utilizador.
- `docker network create`, `ls`, `inspect` e `connect`.
- Comunicação container-to-container.
- DNS interno em redes definidas pelo utilizador.
- Diferença entre porta interna e porta publicada no host.

### 5.4. Storage

- Filesystem gravável do container.
- Bind mounts.
- Named volumes.
- `docker volume create`, `ls`, `inspect` e `rm`.
- Persistência após remoção/recriação do container.
- Mensagem-chave: **volume persistente ≠ backup**.

### 5.5. Docker Compose

- Estrutura de `compose.yaml`.
- `services`.
- `image`.
- `ports`.
- `environment`.
- `networks`.
- `volumes`.
- `depends_on` como ordenação/dependência, distinguindo-o de readiness.
- `docker compose up`, `down`, `ps`, `logs`, `exec` e `config`.

### 5.6. Troubleshooting integrado

- Porta já ocupada.
- Container terminado inesperadamente.
- Serviço sem comunicação de rede.
- Volume não montado como esperado.
- Dependência ainda não disponível.
- Leitura de logs antes de alterar configuração.

---

## 6. Distribuição temporal

| Tempo | Conteúdo / atividade | Tipo predominante |
|---:|---|---|
| 10 min | Enquadramento e ligação à Sessão 1 | Síntese |
| 30 min | Imagens, containers, ciclo de vida e portas | Conceito + prática guiada |
| 25 min | Logs, `exec`, `inspect` e `stats` | Demonstração + prática |
| 30 min | Networking Docker | Conceito + prática |
| 30 min | Storage: bind mounts e volumes | Conceito + prática |
| 15 min | **Intervalo** | — |
| 35 min | Docker Compose | Conceito + demonstração |
| 50 min | Laboratório integrado Symfony + PostgreSQL | Prática |
| 15 min | Troubleshooting, síntese e checklist | Consolidação |
| **240 min** | **Total** | |

---

## 7. Planeamento detalhado

### Bloco 1 — Enquadramento

**Duração:** 10 minutos

#### Questão orientadora

> Na Sessão 1 percebemos o que é um container. Conseguimos agora operar uma pequena aplicação containerizada sem depender de comandos decorados?

#### Mensagem-chave

A Sessão 2 não é sobre construir imagens; é sobre compreender o comportamento dos containers que já existem.

---

### Bloco 2 — Ciclo de vida, imagens e portas

**Duração:** 30 minutos

#### Demonstração

- puxar uma imagem;
- executar um serviço;
- listar containers;
- parar/reiniciar;
- recriar;
- publicar uma porta;
- confirmar acesso com `curl`.

#### Perguntas orientadoras

- O que desaparece quando removemos o container?
- A imagem desaparece?
- Porque existe diferença entre a porta do processo e a porta do host?

---

### Bloco 3 — Observar antes de alterar

**Duração:** 25 minutos

#### Sequência de diagnóstico

```text
estado
  ↓
logs
  ↓
inspect
  ↓
exec (se necessário)
  ↓
recursos
  ↓
decisão
```

#### Comandos de referência

```bash
docker ps
docker logs CONTAINER
docker inspect CONTAINER
docker exec -it CONTAINER sh
docker stats --no-stream
```

`docker exec` deve ser enquadrado como instrumento de diagnóstico, não como forma normal de configurar uma aplicação em produção.

---

### Bloco 4 — Networking Docker

**Duração:** 30 minutos

#### Relação fundamental

```text
Host
 │
 │ porta publicada
 ▼
Container aplicação
 │
 │ rede Docker
 ▼
Container PostgreSQL
```

#### Atividade

- criar uma rede;
- colocar dois containers na rede;
- validar resolução por nome;
- inspecionar a rede;
- distinguir comunicação interna de exposição ao host.

---

### Bloco 5 — Storage

**Duração:** 30 minutos

#### Progressão

```text
filesystem do container
        ↓
   dados efémeros

bind mount
        ↓
ficheiro/diretoria do host

named volume
        ↓
dados geridos pelo Docker
```

#### Atividade

Criar um volume para PostgreSQL, inserir um dado, remover/recriar o container e confirmar que o dado permanece.

#### Mensagem-chave

> Persistência reduz o acoplamento ao ciclo de vida do container; não substitui um backup.

---

## 8. Intervalo

**Duração:** 15 minutos

---

## 9. Bloco 6 — Docker Compose

**Duração:** 35 minutos

### Objetivo

Passar de uma sequência manual de comandos para uma definição declarativa da aplicação multi-container.

### Estrutura conceptual

```text
compose.yaml
   │
   ├── app
   │    ├── image
   │    ├── ports
   │    └── environment
   │
   ├── db
   │    ├── image: postgres:16
   │    └── volume
   │
   ├── network
   └── volume
```

### Comandos essenciais

```bash
docker compose config
docker compose up -d
docker compose ps
docker compose logs
docker compose exec
docker compose down
```

---

## 10. Laboratório integrado — Operar Symfony + PostgreSQL

**Duração:** 50 minutos

### Objetivo

Operar uma aplicação composta por serviço Web e base de dados, sem construir ainda a imagem da aplicação.

### Tarefas

1. Validar o ficheiro Compose.
2. Iniciar a stack.
3. Observar os containers e a rede criada.
4. Confirmar a porta publicada da aplicação.
5. Consultar logs da aplicação e da base de dados.
6. Inspecionar mounts e network settings.
7. Confirmar que PostgreSQL utiliza um named volume.
8. Criar um dado de teste.
9. Recriar o serviço de base de dados sem remover o volume.
10. Confirmar a persistência do dado.
11. Simular um problema simples e seguir a sequência de troubleshooting.

### Resultado esperado

O formando deverá conseguir explicar:

```text
imagem ≠ container
porta interna ≠ porta publicada
filesystem do container ≠ volume
container recriado ≠ dados necessariamente perdidos
Compose ≠ orquestrador de alta disponibilidade
```

---

## 11. Síntese e avaliação formativa

**Duração:** 15 minutos

### Checklist de competências

- [ ] Consigo gerir o ciclo de vida de um container.
- [ ] Consigo identificar a porta publicada.
- [ ] Sei consultar logs e `inspect` antes de alterar configuração.
- [ ] Consigo explicar a função de uma rede Docker.
- [ ] Distingo bind mount de named volume.
- [ ] Consigo validar persistência após recriação de um container.
- [ ] Consigo ler e utilizar um `compose.yaml`.
- [ ] Consigo distinguir dependência de arranque de readiness real.
- [ ] Sei iniciar um troubleshooting estruturado.

---

## 12. Continuidade para a Sessão 3

A Sessão 2 termina com a capacidade de **operar** uma aplicação existente.

A Sessão 3 começa com a questão:

> Como transformamos o código da aplicação numa imagem reproduzível, otimizada, validada, versionada e promovível entre ambientes?

```text
Sessão 2
OPERAR
   ↓
containers + rede + storage + Compose
   ↓
Sessão 3
CONSTRUIR / PREPARAR / PROMOVER
```
