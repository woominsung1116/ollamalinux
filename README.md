# OllamaLinux

A Linux distribution purpose-built for local AI — Ubuntu 24.04 LTS with Ollama and Open WebUI pre-installed, GPU auto-detection, and a first-boot setup wizard.

---

## Features

- **Pre-installed AI stack** — Ollama 0.6.2 and Open WebUI ready on first boot
- **GPU auto-detection** — NVIDIA CUDA, AMD ROCm, and Intel OneAPI detected and configured automatically
- **First-boot wizard** — Interactive TUI to set hostname, create a user, select AI models, and configure services
- **Two flavors** — Server ISO (headless) and Desktop ISO (full GUI)
- **Security by default** — Ollama and Open WebUI bound to `127.0.0.1` only; SSH root login disabled; sysctl hardening applied
- **systemd-managed services** — `ollama.service`, `open-webui.service`, `ollamalinux-monitor.service`, `ollamalinux-firstboot.service`
- **Model management CLI** — `ollamalinux-models` for downloading and managing LLM models

---

## Quick Start

### 1. Download the ISO

Download the latest release from the [Releases](../../releases) page:

| Flavor | File |
|--------|------|
| Server (headless) | `ollamalinux-0.1.0-server-amd64.iso` |
| Desktop (GUI) | `ollamalinux-0.1.0-desktop-amd64.iso` |

Verify the checksum:

```bash
sha256sum -c SHA256SUMS
```

### 2. Write to USB

```bash
# Linux / macOS
sudo dd if=ollamalinux-0.1.0-server-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync

# Or use balenaEtcher / Rufus (Windows/macOS GUI)
```

### 3. Boot and configure

1. Boot from the USB drive
2. The first-boot wizard launches automatically
3. Follow the prompts to set hostname, create a user, select AI models, and enable Open WebUI
4. Access the web interface at `http://127.0.0.1:8080`

---

## System Requirements

| | Minimum | Recommended |
|---|---------|-------------|
| CPU | x86_64, 4 cores | x86_64, 8+ cores |
| RAM | 8 GB | 16 GB+ |
| Storage | 50 GB | 100 GB+ |
| GPU | None (CPU inference) | NVIDIA RTX / AMD RX 6000+ |
| Network | Required (model downloads) | Broadband |

> GPU drivers are downloaded and installed at first boot. An internet connection is required.

---

## Included Software

| Component | Version | Description |
|-----------|---------|-------------|
| Ubuntu | 24.04 LTS (Noble) | Base OS |
| Ollama | 0.6.2 | Local LLM server (`127.0.0.1:11434`) |
| Open WebUI | Latest | Web chat interface (`127.0.0.1:8080`) |
| GRUB | 2.x | Bootloader with OllamaLinux theme |
| Plymouth | — | Branded boot splash |

**Available models at setup** (selected during first-boot wizard):

- Llama 3.2 3B (2.0 GB) — default selection
- Llama 3.1 8B / 70B
- Code Llama 13B
- Mistral 7B, Mixtral 8x7B
- Phi-3 Mini, Gemma 2 9B, Qwen 2.5 7B, DeepSeek-R1 8B

---

## Building

### Prerequisites

- Docker or Podman (auto-detected)
- Linux x86_64 host (or GitHub Actions)

### GitHub Actions (recommended)

Push to `main` to trigger an automatic server ISO build. To build manually or select a flavor:

1. Go to **Actions** → **Build OllamaLinux ISO**
2. Click **Run workflow**
3. Select `server`, `desktop`, or `both`
4. Download the ISO from the workflow artifacts

Tag a release to publish to GitHub Releases:

```bash
git tag v0.1.0
git push origin v0.1.0
```

### Local build

```bash
# Build server ISO (default)
make build

# Build desktop ISO
make build-desktop

# Force a specific container runtime
make build RUNTIME=docker
make build RUNTIME=podman

# Generate SHA256 checksum
make checksum

# Test in QEMU (requires qemu-system-x86_64)
make test
```

Build output: `output/ollamalinux-0.1.0-server-amd64.iso`

Build time: approximately 30–60 minutes depending on network speed.

---

## Project Structure

```
ollamalinux/
├── Makefile                          # Build entry point
├── VERSION                           # Current version (0.1.0)
├── build/
│   ├── Containerfile                 # Docker/Podman build environment (Ubuntu 24.04)
│   └── build.sh                      # Build script run inside container
├── live-build/
│   ├── auto/
│   │   ├── config                    # lb config options (distribution, arch, bootloader)
│   │   ├── build                     # lb build automation
│   │   └── clean                     # lb clean automation
│   └── config/
│       ├── package-lists/
│       │   ├── standard.list.chroot  # Packages in all flavors
│       │   ├── server.list.chroot    # Server-only packages
│       │   └── desktop.list.chroot   # Desktop-only packages
│       ├── hooks/
│       │   ├── 0100-install-ollama.hook.chroot       # Installs Ollama binary
│       │   ├── 0200-install-openwebui.hook.chroot     # Installs Open WebUI
│       │   ├── 0300-configure-gpu.hook.chroot         # GPU driver setup
│       │   ├── 0400-configure-services.hook.chroot    # systemd service configuration
│       │   ├── 0500-fix-initrd.hook.chroot            # initrd fixes
│       │   ├── 0600-harden-system.hook.chroot         # Security hardening
│       │   └── 0700-cleanup.hook.chroot               # Build cleanup
│       └── includes.chroot/
│           ├── etc/systemd/system/   # systemd service units
│           └── usr/local/bin/        # ollamalinux-* CLI tools (copied at build time)
├── scripts/
│   ├── ollamalinux-firstboot.sh      # First-boot TUI wizard (whiptail)
│   ├── ollamalinux-models.sh         # Model management CLI
│   ├── ollamalinux-monitor.sh        # System resource monitor
│   └── test-build.sh                 # Local build test helper
├── branding/
│   ├── grub/                         # GRUB bootloader theme
│   └── plymouth/                     # Boot splash theme
├── .github/workflows/
│   └── build-iso.yml                 # CI/CD: build and release ISOs
└── output/                           # Build artifacts (generated locally)
```

---

## Security

OllamaLinux applies the following security configuration by default:

| Area | Default |
|------|---------|
| Ollama API | Bound to `127.0.0.1:11434` — not exposed to the network |
| Open WebUI | Bound to `127.0.0.1:8080` — not exposed to the network |
| SSH root login | Disabled (`PermitRootLogin no`) |
| SSH auth attempts | Limited to 3 (`MaxAuthTries 3`) |
| Network hardening | Reverse path filtering, SYN cookies, ICMP redirect rejection via sysctl |
| Unused services | `bluetooth.service` and `cups.service` disabled |
| Ollama process limits | `nofile` 1,048,576; `memlock` unlimited (for large model files) |

To expose services remotely, use an SSH tunnel or configure a reverse proxy (nginx, Caddy). Direct network exposure is intentionally not the default.

---

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes and test locally with `make build`
4. Open a pull request against `main`

Bug reports and feature requests are welcome via [GitHub Issues](../../issues).
