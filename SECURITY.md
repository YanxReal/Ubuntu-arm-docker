# Security Policy

## Supported versions

| Version | Supported |
|---|---|
| `main` branch | ✅ |
| Tagged releases (`1.x`) | ✅ |
| Older releases | ❌ |

## Reporting a vulnerability

Please **do not** open public issues for security problems. Instead, report them
privately:

- Use GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
  on the repository (**Security → Report a vulnerability**), or
- Open a minimal issue asking for a private channel if the former is unavailable.

Include, when possible:

- A description of the issue and its impact.
- Steps to reproduce (commands, configuration, versions).
- Any relevant logs (`make logs`, `make logs-grd`).
- Suggested mitigations, if you have them.

You can expect an initial response within a few days. Please allow time for a fix before
public disclosure.

## Security model and scope

**This project is designed for local development environments.** Its defaults are
intentionally weak so that the first run is frictionless:

- The desktop user, VNC and SSH all use the password `admin`.
- The `admin` user has passwordless `sudo` inside the container.
- Published ports bind to all host interfaces by default
  (`6080`, `5902`, `2222`), and the container can reach the network.

Out of scope / by design:

- Weak default credentials and the absence of TLS on VNC/noVNC.
- The lack of authentication on the web UI beyond the VNC password.
- Anything an attacker can do with root inside the container once they have the
  credentials (the container is not a security boundary for its own user).

If you deploy this beyond your machine, at minimum:

1. Change `VNC_PASSWORD` and the `admin` password.
2. Bind ports to loopback in `docker-compose.yml` (for example
   `127.0.0.1:6080:6080`).
3. Switch SSH to key-based authentication and disable password login.
4. Keep the base image and packages up to date (`make reload`).

## Dependency vulnerabilities

The image builds on Ubuntu 26.04 LTS, GNOME 50, GNOME Remote Desktop 50.2, noVNC,
websockify, Helium, Rust, and Node.js. Reports about vulnerable dependencies are welcome
and will be triaged like any other security report.
