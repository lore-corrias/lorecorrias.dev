FROM mcr.microsoft.com/devcontainers/javascript-node

ARG HUGO_VERSION=0.141.0

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends ca-certificates wget && \
  wget -qO- "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz" | tar -xz -C /usr/local/bin hugo && \
  hugo version && \
  wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash - && \
  rm -rf /var/lib/apt/lists/*
