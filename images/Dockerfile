# Omnigent OpenShell sandbox image (UBI 10).
#
# Purpose-built host image for OpenShell-managed sandboxes. Unlike the
# standard host image (Dockerfile / Dockerfile.ubi) which runs as root
# for Modal/Daytona providers, this image follows the OpenShell sandbox
# contract: non-root `sandbox` user, writable venv at /sandbox/.venv,
# and a baked-in /etc/openshell/policy.yaml.
#
# Agent CLIs: Claude Code, Codex, OpenCode, Antigravity (agy), gh.
#
# Build from this POC repo, supplying the Omnigent fork checkout:
#
#   docker build --build-context omnigent-source=../omnigent-oshell-prov -t omnigent-host-openshell:ubi10 -f images/Dockerfile .
#
# The named context is required: a build without it fails instead of
# silently installing an unrelated nightly Omnigent source tree.

# ── Source stage ────────────────────────────────────────
# Select the same package files copied by the Omnigent host image builder.
# UBI 10 uses /usr/bin/python3, so the final stage installs these sources
# into its own venv instead of copying another image Python environment.
FROM scratch AS omnigent-src
COPY --from=omnigent-source /pyproject.toml /setup.py /LICENSE /NOTICE /build/
COPY --from=omnigent-source /sdks /build/sdks
COPY --from=omnigent-source /omnigent /build/omnigent
COPY --from=omnigent-source /examples /build/examples


# ── Native tools builder ─────────────────────────────────
# tmux and bubblewrap are not in UBI 10 repos. Build from source in a
# throwaway stage using Fedora (which has bison/meson/etc.) and COPY
# just the binaries into the final image.
FROM fedora:42 AS native-builder

ARG TMUX_VERSION=3.5a
ARG BWRAP_VERSION=0.11.0

RUN dnf install -y --nodocs \
        gcc make bison libevent-devel ncurses-devel \
        meson libcap-devel curl xz \
 && dnf clean all

RUN curl -fsSL "https://github.com/tmux/tmux/releases/download/${TMUX_VERSION}/tmux-${TMUX_VERSION}.tar.gz" \
      -o /tmp/tmux.tar.gz \
 && tar -xzf /tmp/tmux.tar.gz -C /tmp \
 && cd /tmp/tmux-${TMUX_VERSION} \
 && ./configure --prefix=/usr/local \
 && make -j"$(nproc)" \
 && make install

RUN curl -fsSL "https://github.com/containers/bubblewrap/releases/download/v${BWRAP_VERSION}/bubblewrap-${BWRAP_VERSION}.tar.xz" \
      -o /tmp/bwrap.tar.xz \
 && tar -xf /tmp/bwrap.tar.xz -C /tmp \
 && cd /tmp/bubblewrap-${BWRAP_VERSION} \
 && meson setup builddir --prefix=/usr/local \
 && meson compile -C builddir \
 && meson install -C builddir

# ── Final image ──────────────────────────────────────────
FROM registry.access.redhat.com/ubi10/ubi:latest AS final

ARG NPM_CONFIG_REGISTRY=
ENV NPM_CONFIG_REGISTRY=${NPM_CONFIG_REGISTRY}

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/sandbox/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin" \
    VIRTUAL_ENV="/sandbox/.venv" \
    IS_SANDBOX=1

# System packages: omnigent harness runtime + OpenShell requirements.
# nodejs is available from UBI 10 AppStream — install directly instead
# of COPY'ing from the nodejs image (avoids shared library mismatches).
RUN dnf install -y --nodocs \
        git procps-ng lsof curl unzip bzip2 \
        iproute nftables python3-pip \
        libevent ncurses-libs libcap \
        nodejs npm nss_wrapper \
 && dnf clean all

# tmux + bubblewrap binaries from the native-builder stage.
COPY --from=native-builder /usr/local/bin/tmux /usr/local/bin/tmux
COPY --from=native-builder /usr/local/bin/bwrap /usr/local/bin/bwrap
COPY images/omnigent-shell-user /usr/local/bin/omnigent-shell-user
COPY images/omnigent-user-identity.sh /usr/local/bin/omnigent-user-identity.sh
RUN chmod 0755 /usr/local/bin/omnigent-shell-user \
 && chmod 0644 /usr/local/bin/omnigent-user-identity.sh

# Sandbox account for drivers that honor the image user.
RUN groupadd -r sandbox \
 && useradd -r -g sandbox -d /sandbox -s /bin/bash sandbox

# Git credential helper for private repos over HTTPS.
RUN git config --system credential.helper \
      '!f() { [ "$1" = get ] || return 0; [ -n "$GIT_TOKEN" ] || return 0; printf "username=%s\npassword=%s\n" "${GIT_USERNAME:-x-access-token}" "$GIT_TOKEN"; }; f'

# Agent CLIs — Claude Code, Codex, OpenCode.
RUN npm install -g --no-audit --no-fund \
      @anthropic-ai/claude-code \
      @openai/codex \
      opencode-ai \
 && npm cache clean --force

# Antigravity CLI (agy) — pinned per-arch GitHub release + sha256.
# Keep in sync with deploy/docker/Dockerfile.
ARG AGY_VERSION=1.1.16
ARG AGY_SHA256_AMD64=7742953b7835b457e9102f1357a493913657dfd147435584f609d58356ec085a
ARG AGY_SHA256_ARM64=c71599bb548cf72dfe7a8f6c411b3c7a3623cd4b0f6276bae89c69f769d6c92d
ENV AGY_VERSION=${AGY_VERSION} \
    AGY_SHA256_AMD64=${AGY_SHA256_AMD64} \
    AGY_SHA256_ARM64=${AGY_SHA256_ARM64}
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64)  asset="agy_cli_linux_x64.tar.gz"; sha="$AGY_SHA256_AMD64" ;; \
      aarch64) asset="agy_cli_linux_arm64.tar.gz"; sha="$AGY_SHA256_ARM64" ;; \
      *) echo "ERROR: unsupported arch '$(uname -m)' for agy" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/agy.tar.gz \
      "https://github.com/google-antigravity/antigravity-cli/releases/download/${AGY_VERSION}/${asset}"; \
    echo "${sha}  /tmp/agy.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/agy.tar.gz -C /tmp antigravity; \
    install -m 0755 /tmp/antigravity /usr/local/bin/agy; \
    rm -f /tmp/agy.tar.gz /tmp/antigravity; \
    test -x /usr/local/bin/agy; \
    installed="$(/usr/local/bin/agy --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"; \
    if [ "$installed" != "$AGY_VERSION" ]; then \
      echo "ERROR: agy reports '${installed:-<unparseable>}', expected '$AGY_VERSION'." >&2; \
      exit 1; \
    fi; \
    echo "agy ${AGY_VERSION} pinned (sha256 verified)"

# GitHub CLI (gh) — pinned per-arch release + sha256.
# Keep in sync with deploy/docker/Dockerfile.
ARG GH_VERSION=2.100.0
ARG GH_SHA256_AMD64=e4d4bb4498e8d007abe545b6568926793ace1b6447da598294a610018cb164be
ARG GH_SHA256_ARM64=ea4e7a581a32ccad6cc7923cb1576ac5859ba4b9a16ab22eb8f8a96e78e2e961
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64)  arch="amd64"; sha="$GH_SHA256_AMD64" ;; \
      aarch64) arch="arm64"; sha="$GH_SHA256_ARM64" ;; \
      *) echo "ERROR: unsupported arch '$(uname -m)' for gh" >&2; exit 1 ;; \
    esac; \
    asset="gh_${GH_VERSION}_linux_${arch}.tar.gz"; \
    curl -fsSL -o /tmp/gh.tar.gz \
      "https://github.com/cli/cli/releases/download/v${GH_VERSION}/${asset}"; \
    echo "${sha}  /tmp/gh.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/gh.tar.gz -C /tmp "gh_${GH_VERSION}_linux_${arch}/bin/gh"; \
    install -m 0755 "/tmp/gh_${GH_VERSION}_linux_${arch}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${arch}"; \
    installed="$(/usr/local/bin/gh --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"; \
    [ "$installed" = "$GH_VERSION" ] || { \
      echo "ERROR: gh reports '${installed:-<unparseable>}', expected '$GH_VERSION'." >&2; exit 1; }; \
    echo "gh ${GH_VERSION} pinned (sha256 verified)"

# Omnigent source from the supplied fork checkout.
COPY --from=omnigent-src /build /build

# Create venv with UBI 10's Python and install omnigent + runtime deps.
RUN python3 -m venv /sandbox/.venv \
 && /sandbox/.venv/bin/pip install --no-cache-dir \
      /build /build/sdks/python-client /build/sdks/ui \
      "python-socks[asyncio]" \
 && /sandbox/.venv/bin/pip install --no-cache-dir --no-deps \
      "websockets>=15" \
 && rm -rf /build

# Login shell PATH setup.
RUN echo 'export PATH="/sandbox/.venv/bin:${PATH}"' > /etc/profile.d/omnigent-venv.sh

# Shell init for the sandbox user.
RUN printf '. /usr/local/bin/omnigent-user-identity.sh\nexport PATH="/sandbox/.venv/bin:/usr/local/bin:/usr/bin:/bin"\nexport VIRTUAL_ENV="/sandbox/.venv"\nexport PS1="sandbox@\\h:\\w\\$ "\n' \
      > /sandbox/.bashrc \
 && printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' > /sandbox/.profile

# Codex defaults.
RUN mkdir -p /sandbox/.codex \
  && printf 'model = "gpt-6-luna"\nmodel_reasoning_effort = "medium"\n' > /sandbox/.codex/config.toml

# OpenShell sandbox policy.
COPY images/policy.yaml /etc/openshell/policy.yaml

# OpenCode provider configuration. The API key is resolved at runtime from
# SELF_HOSTED_API_KEY rather than being baked into the image.
COPY images/opencode.json /sandbox/.config/opencode/opencode.json

# Own everything under /sandbox by the sandbox user.
RUN chown -R sandbox:sandbox /sandbox

USER sandbox
WORKDIR /sandbox
ENTRYPOINT ["/bin/bash"]
