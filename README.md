# Server Bootstrap Script

Provision a clean, secure, production-ready Debian-based server in minutes.

Built by [UpHill Solutions](https://uphillsolutions.tech) for internal and client deployments.

---

## What It Does

- Adds a non-root user
- Sets timezone and shell configs
- Installs:
  - Node.js LTS
  - NGINX + Certbot
  - UFW + Fail2Ban
  - Git, Vim, curl, htop, and more
- Configures:
  - Default `.vimrc` and `.bashrc`
  - Dynamic MOTD with system info
  - Web root with fallback 404 page

---

## Usage

SSH into your server and run:

```bash
curl -fsSL https://raw.githubusercontent.com/uhs-robert/server-bootstrap/main/bootstrap.sh | bash
```
