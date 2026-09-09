# Estrutura do Repositório

Este documento define a organização recomendada para os recursos da formação.

## Estrutura global

```text
formacao-kubernetes/
├── README.md
├── .gitignore
├── docs/
├── app/
├── sessao-01/
├── sessao-02/
├── sessao-03/
├── sessao-04/
├── sessao-05/
├── sessao-06/
├── sessao-07/
├── sessao-08/
├── sessao-09/
└── sessao-10/
```

## Estrutura recomendada por sessão

Nem todas as sessões precisam de todas as pastas. Criar apenas as que tenham conteúdo real.

```text
sessao-XX/
├── README.md
├── plano_sessao_X.md          # quando for disponibilizado aos formandos
├── manual_formando.md
├── checklist.md
├── cheat_sheet.md
├── referencias.md
├── labs/
├── scripts/
├── manifests/
├── exemplos/
└── exercicios/
```

### Função de cada elemento

- `README.md` — ponto de entrada da sessão, objetivos, sequência e navegação;
- `manual_formando.md` — conteúdo pedagógico de estudo e consulta;
- `checklist.md` — validações antes/durante/depois do laboratório;
- `cheat_sheet.md` — comandos de consulta rápida;
- `referencias.md` — documentação e bibliografia técnica;
- `labs/` — guiões práticos executados pelo formando;
- `scripts/` — automação auxiliar, nunca substituto da aprendizagem manual;
- `manifests/` — YAML e outros ficheiros declarativos;
- `exemplos/` — exemplos pequenos e isolados;
- `exercicios/` — exercícios sem resolução pública quando esta deva permanecer reservada.

## Conteúdo do formador

Este repositório é público e orientado aos formandos. Recursos como **gabaritos, notas do formador, grelhas de avaliação, scripts de contingência com detalhes internos e apresentações de trabalho** devem permanecer num espaço privado do formador quando não devam ser entregues à turma.

## Convenções de nomes

- sessões: `sessao-01` a `sessao-10`;
- nomes de ficheiros em minúsculas e `snake_case` quando aplicável;
- scripts shell: extensão `.sh` e shebang explícito;
- manifests Kubernetes: nomes descritivos, por exemplo `deployment-app.yaml`;
- evitar espaços nos nomes dos ficheiros executáveis e técnicos.

## Regra de segurança

Nunca versionar:

```text
passwords
tokens
chaves privadas
admin.conf
kubeconfig administrativos
.env reais
join commands com token válido
segredos Kubernetes em claro destinados a ambientes reais
```

Quando for necessário mostrar estrutura de configuração, utilizar placeholders ou ficheiros `.example`.

## Regra pedagógica

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
VALIDAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```

Os scripts devem aparecer depois da compreensão do procedimento que automatizam.
