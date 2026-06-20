FROM vllm/vllm-openai-rocm:v0.22.1-base

# Defaults and Essentials
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN apt-get update && apt-get install -y vim curl procps net-tools \
      iproute2 openssh-server locales git build-essential python3-dev \
      libffi-dev ripgrep ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen

ENV PATH="/root/.local/bin:${PATH}"
RUN mkdir -p "/root/.local/bin"
RUN curl -LsSf https://astral.sh/uv/install.sh | /bin/bash
RUN export VLLM_ROCM_VARIANT=$(curl -s https://wheels.vllm.ai/rocm/vllm | grep -oP 'rocm\d+' | head -1) && \
    export VLLM_VERSION=$(curl -s https://wheels.vllm.ai/rocm/vllm | grep -oP 'vllm-\K[0-9.]+' | head -1) && \
    echo $VLLM_ROCM_VARIANT && \
    echo $VLLM_VERSION
RUN echo "export PATH=\$PATH:/root/.local/bin" > /root/.bashrc
RUN export PATH=$PATH:/root/.local/bin && \
    uv venv /root/.venv && \
    bash -c "source /root/.venv/bin/activate && uv pip install fastokens && uv pip install 'fastapi>=0.100.0,<0.137.0' vllm --extra-index-url https://wheels.vllm.ai/rocm/ --upgrade"

# SSH
RUN mkdir -p /var/run/sshd /root/.ssh && \
    chmod 700 /root/.ssh && \
    ssh-keygen -A
COPY common/ssh/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys && chown root:root /root/.ssh/authorized_keys
