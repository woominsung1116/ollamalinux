PROJECT     := ollamalinux
VERSION     := $(shell cat VERSION 2>/dev/null || echo "0.1.0")
BUILD_DIR   := build
LB_DIR      := live-build
OUTPUT_DIR  := output
CACHE_DIR   := $(BUILD_DIR)/cache
CONTAINER   := $(PROJECT)-builder
IMAGE       := $(PROJECT)-build-env:$(VERSION)

# Auto-detect container runtime: prefer docker, fallback to podman
RUNTIME     := $(shell command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && echo docker || echo podman)

.PHONY: all image build build-desktop clean distclean shell test test-desktop help checksum runtime-check

all: build

help:
	@echo "OllamaLinux Build System"
	@echo "========================"
	@echo "  make image         - Build the container build-environment image"
	@echo "  make build         - Build the OllamaLinux Server ISO"
	@echo "  make build-desktop - Build the OllamaLinux Desktop ISO"
	@echo "  make clean         - Clean live-build artifacts"
	@echo "  make distclean     - Clean everything including container image"
	@echo "  make shell         - Open shell in build container"
	@echo "  make test          - Test ISO with QEMU"
	@echo "  make checksum      - Generate SHA256 checksum"
	@echo ""
	@echo "  Detected runtime: $(RUNTIME)"
	@echo "  Override with: make build RUNTIME=docker"

runtime-check:
	@echo "Using container runtime: $(RUNTIME)"
	@$(RUNTIME) --version

image: runtime-check
	$(RUNTIME) build \
		--platform linux/amd64 \
		-t $(IMAGE) \
		-f $(BUILD_DIR)/Containerfile \
		$(BUILD_DIR)/

build: image
	mkdir -p $(OUTPUT_DIR) $(CACHE_DIR)
	$(RUNTIME) run --rm \
		--platform linux/amd64 \
		--privileged \
		--name $(CONTAINER) \
		-v $(CURDIR)/$(LB_DIR):/build/live-build:Z \
		-v $(CURDIR)/scripts:/build/scripts:ro,Z \
		-v $(CURDIR)/branding:/build/branding:ro,Z \
		-v $(CURDIR)/$(OUTPUT_DIR):/build/output:Z \
		-v $(CURDIR)/$(CACHE_DIR):/build/cache:Z \
		-e PROJECT=$(PROJECT) \
		-e VERSION=$(VERSION) \
		-e FLAVOR=server \
		$(IMAGE)

build-desktop: image
	mkdir -p $(OUTPUT_DIR) $(CACHE_DIR)
	$(RUNTIME) run --rm \
		--platform linux/amd64 \
		--privileged \
		--name $(CONTAINER)-desktop \
		-v $(CURDIR)/$(LB_DIR):/build/live-build:Z \
		-v $(CURDIR)/scripts:/build/scripts:ro,Z \
		-v $(CURDIR)/branding:/build/branding:ro,Z \
		-v $(CURDIR)/$(OUTPUT_DIR):/build/output:Z \
		-v $(CURDIR)/$(CACHE_DIR):/build/cache:Z \
		-e PROJECT=$(PROJECT) \
		-e VERSION=$(VERSION) \
		-e FLAVOR=desktop \
		$(IMAGE)

shell: image
	$(RUNTIME) run --rm -it \
		--platform linux/amd64 \
		--privileged \
		-v $(CURDIR)/$(LB_DIR):/build/live-build:Z \
		-v $(CURDIR)/scripts:/build/scripts:ro,Z \
		-v $(CURDIR)/$(OUTPUT_DIR):/build/output:Z \
		-v $(CURDIR)/$(CACHE_DIR):/build/cache:Z \
		--entrypoint /bin/bash \
		$(IMAGE)

clean:
	$(RUNTIME) run --rm \
		--platform linux/amd64 \
		--privileged \
		-v $(CURDIR)/$(LB_DIR):/build/live-build:Z \
		--entrypoint /bin/bash \
		$(IMAGE) \
		-c "cd /build/live-build && lb clean --purge"

distclean: clean
	rm -rf $(OUTPUT_DIR) $(CACHE_DIR)
	$(RUNTIME) rmi $(IMAGE) 2>/dev/null || true

test:
	@echo "Booting ISO in QEMU..."
	qemu-system-x86_64 \
		-m 8G \
		-smp 4 \
		-cdrom $(OUTPUT_DIR)/$(PROJECT)-$(VERSION)-server-amd64.iso \
		-boot d \
		-device virtio-gpu-pci \
		-display default \
		-net nic -net user,hostfwd=tcp::8080-:8080,hostfwd=tcp::11434-:11434

test-desktop:
	@echo "Booting Desktop ISO in QEMU..."
	qemu-system-x86_64 \
		-m 8G \
		-smp 4 \
		-cdrom $(OUTPUT_DIR)/$(PROJECT)-$(VERSION)-desktop-amd64.iso \
		-boot d \
		-device virtio-gpu-pci \
		-display default \
		-net nic -net user,hostfwd=tcp::8080-:8080,hostfwd=tcp::11434-:11434

checksum:
	cd $(OUTPUT_DIR) && sha256sum *.iso > SHA256SUMS
