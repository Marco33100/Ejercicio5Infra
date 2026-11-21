# Imagen con Terraform + Ansible para no instalar nada en Windows (Ansible no corre nativo en Windows).
FROM python:3.12-slim

ARG TERRAFORM_VERSION=1.9.8
ARG ANSIBLE_CORE_VERSION=2.17.7

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssh-client curl unzip ca-certificates \
 && curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
 && unzip /tmp/terraform.zip -d /usr/local/bin \
 && rm -rf /tmp/terraform.zip /var/lib/apt/lists/*

RUN pip install --no-cache-dir "ansible-core==${ANSIBLE_CORE_VERSION}"

# Cada `apply` crea una VM nueva con otra huella SSH; la VM solo acepta SSH desde la IP del administrador.
ENV ANSIBLE_HOST_KEY_CHECKING=False

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh && mkdir -p /root/.ssh

WORKDIR /work
ENTRYPOINT ["/entrypoint.sh"]
