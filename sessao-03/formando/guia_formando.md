# Guia do Formando — Sessão 3

## Docker II — Build, Imagens, Segurança, Registry e Deployment Single-host

## 1. Objetivo

A Sessão 2 concentrou-se em **operar** containers. Nesta sessão o foco passa para **construir e preparar** o artefacto que será promovido entre ambientes.

```text
Código → Dockerfile → imagem → scan → registry → deploy → update → rollback
```

## 2. Preparar a VM

Os recursos encontram-se no GitHub. Numa VM nova:

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
```

Se o repositório já estiver clonado:

```bash
cd formacao-kubernetes
git pull
cd sessao-03
```

Todos os comandos da sessão assumem que está na raiz:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
test -f formando/docker/Dockerfile && echo 'OK: diretoria correta'
test -x comum/prepare-source.sh && echo 'OK: prepare-source disponível'
```

## 3. Pré-requisitos

- Docker Engine funcional;
- Docker Compose;
- Git;
- `curl`;
- Trivy para o Lab 05;
- acesso à Internet para obter o Symfony Demo e imagens públicas.

Preparar a aplicação:

```bash
./comum/prepare-source.sh
```

Confirmar:

```bash
test -f app/composer.json && echo 'OK: source preparado'
```

## 4. Regra de aprendizagem

Nos Labs 01–06, deverá primeiro executar o processo **manualmente**. Os scripts existem como exemplos de automação e atalhos depois de compreender os passos.

```text
FAZER
  ↓
OBSERVAR
  ↓
EXPLICAR
  ↓
AUTOMATIZAR
```

Não execute um script pela primeira vez sem saber que operações está a automatizar.

No Lab 07 os scripts são usados deliberadamente para integrar o ciclo operacional completo.

## 5. Cenário

A aplicação é a Symfony Demo `v3.1.0`, executada com PHP 8.4 + Apache e PostgreSQL 16.

Os endpoints adicionais são:

```text
/info
/health
/ready
```

`/health` responde à pergunta “o processo da aplicação está operacional?”. `/ready` acrescenta a dependência da base de dados.

## 6. Percurso dos laboratórios

| Lab | Tema | Forma de trabalho | Resultado esperado |
|---:|---|---|---|
| 01 | Dockerfile e build | manual | imagem funcional |
| 02 | Cache e multi-stage | manual; script apenas no fim | imagem otimizada e cache compreendida |
| 03 | Hardening e secrets | experiências manuais | riscos observados e alternativas compreendidas |
| 04 | Healthcheck e operação | Compose manual; wrapper depois | saúde e controlos operacionais validados |
| 05 | Scan, tags e digest | manual | vulnerabilidades interpretadas e identidade compreendida |
| 06 | Registry e promoção | `tag` e `push` manuais; script depois | promoção compreendida |
| 07 | Deploy/update/rollback | automação operacional transparente | ciclo completo validado |

## 7. Regras de trabalho

1. Não colocar tokens ou passwords reais nos ficheiros versionados.
2. Não usar `latest` nos exercícios em que se pretende rastreabilidade.
3. Validar sempre o estado depois de uma alteração.
4. Não confundir persistência com backup.
5. Não confundir Docker `HEALTHCHECK` com probes Kubernetes.
6. Um deployment Compose num único host não é Alta Disponibilidade.
7. Antes de executar um script, saber explicar os passos que ele automatiza.

## 8. Versões de referência

```text
1.0.0      → versão inicial
1.1.0      → atualização válida
1.2.0-rc1  → candidata com falha de healthcheck
```

Imagens públicas:

```text
ghcr.io/skullclamp/symfony-demo
```

## 9. Evidência final

No final deverá conseguir mostrar:

- Dockerfile interpretado;
- imagem construída manualmente;
- cache observada e explicada;
- multi-stage compreendido;
- secret inadequado identificado experimentalmente;
- Compose executado manualmente;
- scan executado;
- tag e digest explicados;
- `docker tag` e `docker push` executados quando houver namespace próprio;
- deployment `1.0.0`;
- update `1.1.0`;
- falha `1.2.0-rc1` detetada;
- rollback `1.1.0`;
- dados preservados.
