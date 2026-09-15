from pathlib import Path

p = Path('sessao-05-06/labs/laboratorio_integrado_sessao_5.md')
text = p.read_text()
old = '''### Como interpretar

```text
get pods       → deve ser permitido
 delete pods    → deve ser negado
--as=...        → simula a identidade da ServiceAccount indicada
```

**Esperado:** primeiro comando `yes`; segundo comando `no`.
'''
new = '''### Como interpretar os comandos e flags

```text
kubectl auth can-i get pods
→ pergunta à API se a identidade indicada pode executar o verbo get sobre Pods

kubectl auth can-i delete pods
→ testa deliberadamente uma operação que não deve estar autorizada

--as=system:serviceaccount:lab-admin:app-reader
→ simula a chamada como a ServiceAccount app-reader

-n lab-admin
→ avalia a autorização no Namespace onde a Role é válida
```

### O que observar para validar

**Esperado:** primeiro comando `yes`; segundo comando `no`.

Isto prova menor privilégio: a identidade tem a capacidade necessária para leitura, mas não ganha automaticamente permissões de escrita/destruição.
'''
if old not in text:
    raise SystemExit('Bloco RBAC esperado não encontrado')
p.write_text(text.replace(old, new, 1))
