#!/usr/bin/env python3
import re, sys
from pathlib import Path
import yaml
root=Path(__file__).resolve().parents[1]
errors=[]
links=re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
secrets=[("token kubeadm literal",re.compile(r"kubeadm\s+join.+--token\s+(?!<)[a-z0-9]{6}\.[a-z0-9]{16}",re.I)),("chave privada",re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"))]
for path in root.rglob("*.md"):
    if ".git" in path.parts: continue
    text=path.read_text(encoding="utf-8")
    for target in links.findall(text):
        target=target.strip().split("#",1)[0]
        if target and not target.startswith(("http://","https://","mailto:")) and not (path.parent/target).resolve().exists():
            errors.append(f"{path.relative_to(root)}: link inexistente: {target}")
    for label,pattern in secrets:
        if pattern.search(text): errors.append(f"{path.relative_to(root)}: possível {label}")
for pattern in ("*.yaml","*.yml"):
    for path in root.rglob(pattern):
        if ".git" in path.parts or ".github/workflows" in path.as_posix(): continue
        try: list(yaml.safe_load_all(path.read_text(encoding="utf-8")))
        except Exception as exc: errors.append(f"{path.relative_to(root)}: YAML inválido: {exc}")
if errors:
    print("\n".join(errors)); sys.exit(1)
print("Validação concluída sem erros.")
