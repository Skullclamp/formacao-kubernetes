#!/usr/bin/env bash
# Verificação apenas de leitura.
set -u

ok=0; avisos=0; falhas=0
pass(){ printf '[OK] %s\n' "$1"; ok=$((ok+1)); }
warn(){ printf '[AVISO] %s\n' "$1"; avisos=$((avisos+1)); }
fail(){ printf '[FALHA] %s\n' "$1"; falhas=$((falhas+1)); }

echo "=== Preflight Kubernetes — $(hostname) ==="

cpus=$(nproc 2>/dev/null || echo 0)
mem_kb=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
mem_mb=$((mem_kb/1024))
(( mem_mb >= 1900 )) && pass "RAM >= ~2 GiB (${mem_mb} MiB)" || warn "RAM baixa (${mem_mb} MiB)"
(( cpus >= 2 )) && pass "CPU >= 2 vCPU (${cpus})" || warn "CPU < 2 vCPU (${cpus})"

swapon --noheadings 2>/dev/null | grep -q . && fail "Swap ativa" || pass "Swap desativada"
lsmod | grep -q '^overlay' && pass "overlay carregado" || fail "overlay não carregado"
lsmod | grep -q '^br_netfilter' && pass "br_netfilter carregado" || fail "br_netfilter não carregado"

[[ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" == "1" ]] && pass "ip_forward=1" || fail "ip_forward != 1"
[[ "$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null)" == "1" ]] && pass "bridge-nf-call-iptables=1" || fail "bridge-nf-call-iptables != 1"

[[ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" == "cgroup2fs" ]] && pass "cgroup v2" || fail "cgroup v2 não confirmado"

timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qi '^yes$' && pass "Relógio sincronizado" || warn "NTP não confirmado"

for h in k8s-cp-01 k8s-wk-01; do
  getent hosts "$h" >/dev/null 2>&1 && pass "$h resolve" || warn "$h não resolve"
done

systemctl is-active --quiet containerd 2>/dev/null && pass "containerd ativo" || fail "containerd inativo"

if [[ -f /etc/containerd/config.toml ]] && grep -Eq 'SystemdCgroup[[:space:]]*=[[:space:]]*true' /etc/containerd/config.toml; then
  pass "SystemdCgroup=true"
else
  fail "SystemdCgroup=true não confirmado"
fi

[[ -S /run/containerd/containerd.sock ]] && pass "socket containerd disponível" || fail "socket containerd indisponível"

for c in kubeadm kubelet kubectl; do
  command -v "$c" >/dev/null 2>&1 && pass "$c instalado" || warn "$c ainda não instalado"
done

echo
echo "Resumo: OK=$ok | Avisos=$avisos | Falhas=$falhas"
(( falhas > 0 )) && exit 2 || exit 0
