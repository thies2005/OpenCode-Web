FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git bash openssh-client nodejs npm \
    procps tini \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://opencode.ai/install | bash
RUN ln -sf /bin/bash /usr/bin/bash || true

ENV SHELL=/bin/bash
ENV PATH="/root/.opencode/bin:${PATH}"
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]
