FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    ovmf \
    swtpm \
    swtpm-tools \
    novnc \
    websockify \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /iso /data/tpm

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 6080 5900 3389

CMD ["/start.sh"]
