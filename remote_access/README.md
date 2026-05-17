# Remote Access

Supporting infrastructure for reaching the manufacturing stack host from outside the local network. These services are operational utilities — not part of the core stack — but are a provided for remote access to services running on this machine.

## Services

| Service | Port | Purpose |
| ------- | ---- | ------- |
| [wg-easy](https://github.com/wg-easy/wg-easy) | 8820/TCP (Web UI), 51820/UDP (VPN) | WireGuard VPN — encrypted tunnel for remote access to the host |
| [cloudflare-ddns](https://github.com/timothyjmiller/cloudflare-ddns) | — | Dynamic DNS — keeps the host's public hostname pointed at its current public IP in Cloudflare |

## Attribution

**wg-easy** is open-source software developed and maintained by the [wg-easy contributors](https://github.com/wg-easy/wg-easy/graphs/contributors), made freely available under the [AGPL-3.0 license](https://github.com/wg-easy/wg-easy/blob/master/LICENSE). WireGuard® is a registered trademark of Jason A. Donenfeld.

**cloudflare-ddns** is open-source software developed by [Timothy Miller](https://github.com/timothyjmiller) and contributors, available at <https://github.com/timothyjmiller/cloudflare-ddns>.

## System Requirements

Both services are lightweight relative to the core stack. Neither has a measured idle baseline because resource use is negligible at rest and highly traffic-dependent under load.

| Service | Notes |
| ------- | ----- |
| wg-easy | Small constant footprint; VPN throughput scales with active client traffic. Stores WireGuard server keys and client configs in a Docker volume (`wg_data`). |
| cloudflare-ddns | Stateless — periodic HTTP calls to detect public IP and update DNS. No volume storage. |

See each service's README for container-specific configuration and resource tuning.

---

## SSH Keys

SSH keys provide secure, passwordless authentication to remote services. Beyond replacing password-based GitHub access — which GitHub [no longer supports for Git operations](https://github.blog/changelog/2021-08-12-git-operations-made-by-github-actions-will-use-the-github_token/) — they are a general security best practice: each machine gets its own key pair, access can be revoked per key, and private keys never leave the host.

If you have not already set up an SSH key for GitHub, follow the official guide:

**[Connecting to GitHub with SSH →](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)**

The guide covers key generation, adding the key to `ssh-agent`, and registering the public key with your account. The standard `ed25519` key it produces (`~/.ssh/id_ed25519`) is also used by the optional environment (.env) file management scripts (`push_envs.sh` / `pull_envs.sh`) described in the main [README.md](../README.md) — a convenient secondary benefit of a practice worth establishing regardless.

---

## WireGuard VPN — wg-easy

[wg-easy](https://github.com/wg-easy/wg-easy) packages a WireGuard VPN server with a browser-based management UI. It handles key generation, client configuration, QR codes, and connection statistics without requiring direct interaction with WireGuard's command-line tools.

| | |
| --- | --- |
| **Web UI** | <http://localhost:8820> (local only — access via VPN once configured) |
| **VPN endpoint** | UDP 51820 — must be reachable from the internet (forward this port on your router) |

See [wg-easy/README.md](wg-easy/README.md) for full setup instructions, including first-run configuration, WSL2 compatibility notes, and client management.

---

## Dynamic DNS — cloudflare-ddns

[cloudflare-ddns](https://github.com/timothyjmiller/cloudflare-ddns) keeps Cloudflare DNS records for your hostname pointed at the host's current public IP. It runs as a background container, polling on a configurable schedule (default: every 5 minutes), and is required when the host does not have a static IP — which is the common case for residential or small-business internet connections.

It uses `network_mode: host` to observe the real public interface rather than a Docker bridge address, and exposes no ports of its own.

See [cloudflare-ddns/README.md](cloudflare-ddns/README.md) for setup instructions, including Cloudflare API token creation and `.env` configuration.
