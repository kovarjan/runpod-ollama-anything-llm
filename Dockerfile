ARG ARG_UID=1000
ARG ARG_GID=1000

# Base NVidia CUDA ollama image
FROM mintplexlabs/anythingllm:latest AS base
USER root

# Install Python plus openssh, which is our minimum set of required packages.
RUN apt-get update -y && \
    apt-get install -y python3 python3-pip python3-venv && \
    apt-get install -y --no-install-recommends openssh-server openssh-client git git-lfs curl htop mc && \
    python3 -m pip install --upgrade pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Install ollama runner
RUN echo "Installing Ollama LLM runner"
RUN curl -fsSL https://ollama.com/install.sh | sh

# Install Cuda and Nvidia container toolkit
ENV PATH="/usr/local/cuda/bin:${PATH}"
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

RUN curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

RUN apt-get update && apt-get install -y nvidia-container-toolkit nano mc

# Install huggingface cli
RUN pip install huggingface-hub

USER anythingllm

# Install collector dependencies
WORKDIR /app/collector
ENV PUPPETEER_DOWNLOAD_BASE_URL=https://storage.googleapis.com/chrome-for-testing-public 
RUN yarn install --production --network-timeout 100000 && yarn cache clean
RUN node node_modules/puppeteer/install.mjs

# Setup environment
WORKDIR /app

ENV NODE_ENV=production
ENV ANYTHING_LLM_RUNTIME=docker
ENV OLLAMA_MODELS=/app/server/storage/ollama/models

# Create aliases for container sotrase so it has a single volume storage - mounting point: /app/server/storage
RUN mkdir -p /app/server/storage
RUN mkdir -p /app/server/storage/ollama
RUN mv /app/server/.env /app/server/storage/.env && ln -s /app/server/storage/.env /app/server/.env

# Expose the server port
EXPOSE 3001

# Setup the healthcheck
HEALTHCHECK --interval=1m --timeout=10s --start-period=1m \
  CMD /bin/bash /usr/local/bin/docker-healthcheck.sh || exit 1

COPY --chmod=755 start-ssh-only.sh /start.sh
ENTRYPOINT [ "/bin/bash" ]

CMD [ "/start.sh" ]
