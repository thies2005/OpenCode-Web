FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git bash openssh-client \
    procps tini \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://opencode.ai/install | bash

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENV SHELL=/bin/bash
ENV PATH="/root/.opencode/bin:${PATH}"
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "-c", "/entrypoint.sh restore && exec opencode web --hostname 0.0.0.0 --port 4096"]
