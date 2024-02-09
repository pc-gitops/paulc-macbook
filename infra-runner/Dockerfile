ARG BASE_IMAGE
FROM $BASE_IMAGE

ARG TARGETARCH
ARG INFRA_EXEC_VERSION
ARG INFRA_EXEC_URL_PREFIX
ARG INFRA_EXEC_NAME

# Switch to root to have permissions for operations
USER root

# terraform
ADD ${INFRA_EXEC_URL_PREFIX}${INFRA_EXEC_VERSION}/${INFRA_EXEC_NAME}_${INFRA_EXEC_VERSION}_linux_${TARGETARCH}.zip ${INFRA_EXEC_NAME}_${INFRA_EXEC_VERSION}_linux_${TARGETARCH}.zip
RUN apk update && apk upgrade && apk add --no-cache bash && apk add unzip git jq curl envsubst aws-cli kubectl && \
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq >/dev/null && \
    unzip -q ${INFRA_EXEC_NAME}_${INFRA_EXEC_VERSION}_linux_${TARGETARCH}.zip -d /usr/local/bin/ && \
    rm ${INFRA_EXEC_NAME}_${INFRA_EXEC_VERSION}_linux_${TARGETARCH}.zip && \
    mv /usr/local/bin/${INFRA_EXEC_NAME} /usr/local/bin/terraform && \
    chmod +x /usr/local/bin/terraform && \
    addgroup -S infra && \
    adduser --home /home/infra --shell /bin/bash --ingroup infra --system --uid 1000 infra

ADD resources/image-gitconfig /home/infra/.gitconfig
RUN chmod 777 /home/infra/.gitconfig && \
    chown infra:infra /home/infra/.gitconfig
# Switch back to the non-root user after operations
USER infra:infra
