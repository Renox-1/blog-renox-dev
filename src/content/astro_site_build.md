---
title: "Building and Deploying My Astro Main Site"
snippet: "Creating my main site with Astro was more than just spinning up a template — I learned about ARM64 builds in GitHub Actions, ditched Vanta.js for a custom twinkling star background, and even built a playful toast notification for email clicks."
author: Benjamin Malek
tags: ['Astro', 'Web Development', 'DevOps', 'Automation']
date: '2025-08-09'
---

I wanted a site that blended my professional portfolio with personal projects, and I wanted it to run entirely in my own infrastructure. That meant picking the right tools for building, styling, and deploying — while also adding some personal touches to make it feel *mine*.  

---

## Step 1 – Choosing the Tech Stack
Astro stood out immediately. It's focus on **server-side rendering** (perfect for more static sites like mine) and **built-in support for Markdown** — ideal for pulling in blog posts without extra complexity.  
The decision also set me up for a lightweight, component-driven architecture that could scale with future features.

---

## Step 2 – Project Setup
I started the project like this:
```bash
npm create astro@latest
```
From there, I installed **Tailwind CSS** for styling, set up key components (`Header`, `Footer`, `Section`, `ResumeItem`), and built the three main pages:
- `index.astro` for the home page and highlights.
- `about.astro` for a deeper, get-to-know-me profile.
- `resume.astro` for a formatted version of my resume.  

This setup made it easy to keep the design consistent across the different pages.

---

## Step 3 – Deployment Pipeline
The plan: build a container image in GitHub Actions, push it to GHCR, and have my K3s cluster pull updates automatically.  
The Containerfile was straightforward, but the GitHub Actions workflow caused trouble when building for ARM64 (again).

My **initial GitHub Actions workflow** looked like this:

```yaml
name: Build and Push to GHCR

on:
  push:
    branches:
      - main 

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write 

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          platforms: linux/arm64
          file: Containerfile
          tags: ghcr.io/renox-1/renox-dev:latest
```

Everything looked fine — but the build failed when targeting `linux/arm64`.

**The fix:** ARM64 builds in GitHub Actions require enabling QEMU emulation first. Adding `docker/setup-qemu-action@v3` before the build step solved it.

My **working GitHub Actions workflow**:

```yaml
name: Build and Push to GHCR

on:
  push:
    branches:
      - main

jobs:
  build-and-push:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: linux/arm64

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push Docker image
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          platforms: linux/arm64
          file: Containerfile
          tags: ghcr.io/renox-1/renox-dev:latest
```

Once this change was in place, the ARM64 container built and pushed successfully.

---

## Step 4 – Adding the Animated Background
One thing I knew from the start — I wanted a **subtle animated background** to give the site some life.  
My first attempt was with **Vanta.js**, but I couldn’t get the asset loading order right. It just wouldn’t initialize properly in Astro.

Instead, I went for a custom canvas animation to get the nice **twinkling stars** you see now.  
The result was perfect — light on resources, visually appealing, and it fit right into my `BaseLayout.astro`.
*One day I will learn how to do frontend properly...*

---

## Step 5 – Toast Notifications for Email Copy
I wanted something fun and interactive for when users click my email in the footer or the "Email Me" button.  
The idea: a **toast notification** that briefly pops up to confirm the email was copied to their clipboard.

It took a few iterations to get the timing and styling right — especially making sure it triggered only when expected — but now it works smoothly and adds a nice personal touch.

---

## Step 6 – Going Live
Once everything was working locally, I deployed to my **K3s cluster** running on Raspberry Pi, fronted by a **Cloudflare Tunnel**.  
Now, every push to the `main` branch in GitHub triggers a new container build and automatic redeployment.

---

**Final Thoughts:**  
This project wasn’t just about getting a website online — it was about building something I fully control, from code to infrastructure. Along the way, I learned a few quirks of ARM64 builds, found joy in tiny UI details like toasts, and even picked up some light canvas animation work.  
The site is now live, fast, and looks great! Time to go back in and break things!
