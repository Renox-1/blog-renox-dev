---
title: "Adding my domain's TLS certificate to my local network"
snippet: "Rebuilding a TLS certificate workflow for my Raspberry Pi K3s cluster wasn’t straightforward — Porkbun’s webhook didn’t support ARM out of the box. Here’s how I rebuilt the image, integrated it with cert-manager, issued a wildcard cert, and synced it across all namespaces."
author: Benjamin Malek
tags: ['Kubernetes', 'Networking', 'Automation', 'DevOps']
date: '2025-08-07'
---

When you run a Kubernetes cluster in your homelab — especially on ARM-based hardware like Raspberry Pi — adding TLS certificates can be trickier than it seems. My goal was simple: get a trusted certificate from my domain registrar (Porkbun) into my K3s cluster so I could use HTTPS across my services. The journey, however, included unsupported webhooks, architecture mismatches, and a few creative workarounds.

---

## Installing cert-manager

I started by installing [`cert-manager`](https://cert-manager.io/), which is the go-to tool for managing TLS certificates in Kubernetes. It handles issuance, renewal, and integration with various DNS providers. The catch? Porkbun isn’t natively supported.  

That meant I needed to install an additional webhook component to bridge the gap between cert-manager and Porkbun’s DNS API.

---

## Porkbun Webhook for ARM

I found [mdonoughe/porkbun-webhook](https://github.com/mdonoughe/porkbun-webhook), which works great — unless you’re on ARM. Since my cluster runs on Raspberry Pis, I had to rebuild the Docker image for `arm64`.  

Here’s what I did:

1. Installed `qemu-user-static` so I could build for ARM architecture.  
2. Tried building on my Windows machine:
    ```bash
    podman build --arch=arm64 -t renox/porkbun-webhook:arm64 .
    ```
   Unfortunately, it just wasn't able to complete a full build for me.  
3. Switched gears and SSH’ed into one of my Raspberry Pis to build natively. Bingo!  
4. Pulled the image back to my main machine and prepared to update the Helm chart.

---

## Updating the Helm Chart

The webhook’s Helm chart still pointed to the default image, so I updated it to use my rebuilt version:

```yaml
image:
  repository: docker.io/renoxgg/porkbun-webhook
  tag: arm64
  pullPolicy: IfNotPresent
```

Then I deployed it to my cluster:

```bash
helm install porkbun-webhook ./deploy/porkbun-webhook   --namespace cert-manager   --set groupName=acme.renox.dev
```

---

## Testing with a Certificate

To confirm everything was working, I created a test certificate for `test.renox.dev`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: test-renox-cert
  namespace: cert-manager
spec:
  secretName: test-renox-cert-tls
  issuerRef:
    name: letsencrypt-porkbun
    kind: ClusterIssuer
  dnsNames:
    - test.renox.dev
```

After applying it, I checked the status:
```bash
kubectl get certificates -n cert-manager
```
But after several minutes, it was still showing `Ready: False`.

---

## Debugging the Issue

Looking at the logs revealed the problem:
```bash
kubectl logs -n cert-manager -l app=cert-manager -f
```
Output:
```
[porkbun.acme.porkbun.com] is forbidden:
User "system:serviceaccount:cert-manager:cert-manager" cannot create resource "porkbun" in API group "acme.porkbun.com" at the cluster scope
```

Cert-manager simply didn’t have permission to create the needed resource. The fix was straightforward: I created the necessary Roles and RoleBindings to give it access to the webhook resources.

After that, I reissued the certificate — and within about a minute, I was seeing `Ready: True`.

---

## Wildcard Certificate

With the test working, it was time for the real goal: a wildcard certificate for `*.renox.dev`.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-renox-dev-cert
  namespace: cert-manager
spec:
  secretName: wildcard-renox-dev-cert-tls
  issuerRef:
    name: letsencrypt-porkbun
    kind: ClusterIssuer
  commonName: '*.renox.dev'
  dnsNames:
    - '*.renox.dev'
```

Applied it, waited a short while, and got `Ready: True`. Success.

---

## Bonus: Syncing the Secret Across All Namespaces

I use my domain for many services, so having the TLS secret in just one namespace wasn’t ideal. Enter [Kubernetes Replicator](https://github.com/mittwald/kubernetes-replicator), a neat tool that automatically copies secrets to other namespaces.

I installed it:
```bash
helm repo add mittwald https://helm.mittwald.de
helm upgrade --install replicator mittwald/replicator --namespace kube-system
```

Then I annotated the secret to replicate everywhere:
```bash
kubectl annotate secret wildcard-renox-dev-cert-tls -n cert-manager replicator.v1.mittwald.de/replicate-to="*"
```

Now, every namespace has access to the wildcard certificate automatically.

---

**Final Thoughts:**  
What started as a quick TLS setup turned into a mini deep dive into cross-architecture builds, Kubernetes RBAC, and secret replication. In the end, the setup is solid, automated, and ready for future service deployments — with only a little head bashing along the way!
