---
title: "Self-Hosting My Own Website"
snippet: "From setting up Cloudflare tunnels to deploying Nginx in my Raspberry Pi-powered K3s cluster, here’s how I brought renox.dev and blog.renox.dev online — fully self-hosted and secured."
author: Benjamin Malek
tags: ['Kubernetes', 'Networking', 'Automation', 'DevOps']
date: '2025-08-08'
---

Running your own website can be as simple as spinning up a WordPress instance somewhere — but I wanted full control. I decided to host both **renox.dev** and **blog.renox.dev** myself, running on my K3s cluster powered by Raspberry Pis. My plan was to route all traffic through Cloudflare tunnels for security, start with simple “coming soon” pages, and eventually build out full sites.

---

## Step 1: Setting Up Cloudflare

The first step was getting Cloudflare in place to act as my CDN and tunnel endpoint.

1. I created a free Cloudflare account.
2. Updated my Porkbun DNS to use Cloudflare’s nameservers.
3. Deployed the `cloudflared` client to my K3s cluster following [Cloudflare’s Kubernetes guide](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/kubernetes/).
4. As a bonus, I updated my existing cronjob that managed my `vpn.renox.dev` IP to now update through Cloudflare instead of Porkbun.

---

## Step 2: Creating and Configuring the Tunnels

With Cloudflare ready, I set up the tunnels:

- Created a new tunnel via the Cloudflare dashboard.
- Installed the `cloudflared` client on my Ubuntu WSL environment for easier tunnel management.
- Logged in and generated credentials:
    ```bash
    cloudflared login
    cloudflared tunnel token --cred-file creds.json renox_dev_tunnel
    ```
- Created a dedicated namespace:
    ```bash
    kubectl create namespace cloudflared
    ```
- Stored the tunnel credentials in a Kubernetes secret:
    ```bash
    kubectl create secret generic cloudflare-tunnel-creds --from-file=creds.json -n cloudflared
    ```
- Used Cloudflare’s standard deployment YAML (slightly modified to use the credentials secret) to deploy the tunnel.

After applying the YAML, I checked the logs and confirmed the tunnel was connected.

---

## Step 3: Building the Websites

For now, I wanted a minimal proof-of-concept: an Nginx container serving a single-line HTML file.

```html
<html><body><h1>Coming Soon to renox.dev</h1></body></html>
```

I created two GitHub repos:  
- [renox-dev](https://github.com/Renox-1/renox-dev)  
- [blog-renox-dev](https://github.com/Renox-1/blog-renox-dev)  

Each repo had:
- A `Containerfile` defining the Nginx setup.
- A GitHub Action to build and push the container image to GHCR (remembering to build for ARM64 for the Pis).

---

## Step 4: Deploying renox.dev

I started with the main site:

1. Created the namespace:
    ```bash
    kubectl create namespace renoxdev
    ```
2. Applied a deployment for the Nginx container:
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: renox-dev
      namespace: renoxdev
      labels:
        app: renox-dev
    spec:
      selector:
        matchLabels:
          app: renox-dev
      template:
        metadata:
          labels:
            app: renox-dev
        spec:
          containers:
            - name: renox-dev
              image: ghcr.io/renox-1/renox-dev:latest
              imagePullPolicy: Always
              ports:
                - containerPort: 80
    ```
3. Exposed it internally with:
    ```bash
    kubectl expose deployment renox-dev -n renoxdev
    ```

---

## Step 5: Routing Through Cloudflare

To make the site available externally, I configured the tunnel to route requests for `renox.dev` and `www.renox.dev` to the service in my cluster.

`config.yaml`:
```yaml
tunnel: <my_tunnel_id>

originRequest:
  connectTimeout: 30s

ingress:
  - hostname: renox.dev
    service: http://renox-dev.renoxdev.svc.cluster.local:80
  - hostname: www.renox.dev
    service: http://renox-dev.renoxdev.svc.cluster.local:80
```

I updated the `cloudflared` deployment to mount this config, reapplied it, and after a few moments, both domains were serving my “coming soon” page.

---

## Step 6: Deploying blog.renox.dev

The process was the same:
1. New namespace.
2. New Nginx deployment.
3. Add another ingress rule to the `config.yaml`:
    ```yaml
    - hostname: blog.renox.dev
      service: http://blog-renox-dev.blogrenoxdev.svc.cluster.local:80
    ```

After redeploying, both sites were live, secure, and routed entirely through Cloudflare.

---

**Final Thoughts:**  
This setup gives me a fast, secure, and fully self-hosted foundation for both my main site and blog. With Cloudflare tunnels, I don’t have to open ports directly to the internet, and with Kubernetes, scaling or replacing components is straightforward. Now that the infrastructure is in place, the real fun — building the sites themselves — can begin.
