FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git bash openssh-client nodejs npm \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://opencode.ai/install | bash

ENV PATH="/root/.opencode/bin:${PATH}"
WORKDIR /workspace

CMD ["opencode", "web", "--hostname", "0.0.0.0", "--port", "4096"]
