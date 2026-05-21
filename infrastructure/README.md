# Infrastructure

Foundational services that support user-facing apps but are not standalone applications themselves. Includes object storage, message brokers, and other shared backend primitives.

## Services

| Service | Port | Purpose | Idle RAM | Base Storage |
| ------- | ---- | ------- | -------- | ------------ |
| [Garage](https://garagehq.deuxfleurs.fr) | [3900](http://localhost:3900) | S3-compatible object store | ~30 MB | ~15 MB |
| name-proxy *(optional)* | [80](http://localhost) | Subdomain access proxy for all services | ~5 MB | — |
| lan-dns *(optional)* | 53 | LAN DNS so edge computers reach services by hostname | ~5 MB | — |

---

See each service's `README.md` for setup instructions and first-run notes.
