# Hardening adicional — apenas após validação da imagem

No laboratório principal foram validados controlos conservadores:

```yaml
automountServiceAccountToken: false
seccompProfile:
  type: RuntimeDefault
allowPrivilegeEscalation: false
```

Não se força `runAsNonRoot`, `readOnlyRootFilesystem` ou `capabilities.drop: ["ALL"]` neste pacote, porque a imagem Symfony/Apache deve ser testada especificamente para esses controlos. O objetivo pedagógico é reforçar que **hardening não deve ser aplicado cegamente**.

Antes de adicionar controlos adicionais, validar:

- UID/GID efetivo da imagem;
- necessidade de bind a portas privilegiadas;
- diretórios de escrita necessários ao PHP/Apache;
- capacidades Linux realmente usadas.
