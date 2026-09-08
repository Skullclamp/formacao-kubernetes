# Lab 6 — Troubleshooting Integrado

**Duração prevista:** 40 minutos  
**Objetivo:** diagnosticar uma falha através de evidências antes de efetuar alterações.

## Método obrigatório

```text
Sintoma
   ↓
docker compose ps
   ↓
docker compose logs
   ↓
docker inspect
   ↓
docker network inspect
   ↓
validar environment / ports / mounts
   ↓
hipótese
   ↓
correção
   ↓
validação
```

Não comece por alterar ficheiros aleatoriamente.

## 1. Estado de referência

```bash
docker compose ps
curl http://localhost:8080/info
curl http://localhost:8080/health
curl http://localhost:8080/ready
```

A aplicação deverá estar funcional antes de o desafio começar.

## 2. Receber o incidente

O formador irá introduzir **uma falha controlada** no seu ambiente.

Não será indicada a causa. Trabalhe apenas a partir do sintoma e das evidências que conseguir recolher.

## 3. Diagnóstico

Utilize a ficha em [`../desafios/troubleshooting.md`](../desafios/troubleshooting.md).

Registe:

- sintoma;
- primeira evidência;
- logs relevantes;
- hipótese;
- validação da hipótese;
- causa raiz;
- correção;
- validação final.

## 4. Validação final

```bash
docker compose ps
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/info
```

## 5. Explicação

Em cerca de 60 segundos, explique ao formador:

1. qual era o sintoma;
2. que evidência recolheu;
3. qual era a causa;
4. que alteração efetuou;
5. como confirmou a recuperação.

## Desafio adicional

A aplicação estar com `/health` funcional garante obrigatoriamente que está pronta para servir pedidos que necessitam da base de dados?

Justifique utilizando `/health` e `/ready`.
