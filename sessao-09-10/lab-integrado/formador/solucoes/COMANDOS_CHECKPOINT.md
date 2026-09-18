# Comandos de checkpoint — Laboratório Integrado Sessões 9–10

Assumir:

~~~bash
cd ~/formacao-kubernetes/sessao-09-10/lab-integrado
export NS=s10-validacao
~~~

## Preflight

~~~bash
bash preflight/validar-baseline.sh
~~~

## CP1 — resources/probes

~~~bash
kubectl -n "$NS" get deployment symfony-demo   -o jsonpath='cpu={.spec.template.spec.containers[0].resources.requests.cpu}{" liveness="}{.spec.template.spec.containers[0].livenessProbe.httpGet.path}{" readiness="}{.spec.template.spec.containers[0].readinessProbe.httpGet.path}{"\n"}'
~~~

## CP1 — HPA

~~~bash
kubectl -n "$NS" get hpa
kubectl -n "$NS" top pods
~~~

## CP2 — Kustomize

~~~bash
kubectl -n "$NS" get deployment symfony-demo-kustomize-dev
kubectl -n "$NS" get configmap symfony-demo-kustomize-config-dev
kubectl -n "$NS" get endpointslices   -l kubernetes.io/service-name=symfony-demo-kustomize-dev
~~~

## CP2 — Helm

~~~bash
helm status symfony-demo-helm --namespace "$NS"
helm history symfony-demo-helm --namespace "$NS"
kubectl -n "$NS" get deployment,service | grep symfony-demo-helm
~~~

## CP3 — candidata

~~~bash
kubectl -n "$NS" get deployment symfony-demo
kubectl -n "$NS" get rs
kubectl -n "$NS" get pods -l app=symfony-demo -o wide
kubectl -n "$NS" get events --sort-by='.lastTimestamp' | tail -25
~~~

## CP3 — rollback

~~~bash
kubectl -n "$NS" rollout history deployment/symfony-demo
kubectl -n "$NS" rollout undo deployment/symfony-demo
kubectl -n "$NS" rollout status deployment/symfony-demo --timeout=120s
~~~
