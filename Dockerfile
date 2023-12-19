FROM ghcr.io/celestiaorg/orchestrator-relayer:v1.0.1 AS orchestrator-relayer

FROM ghcr.io/celestiaorg/celestia-app:v1.3.0 AS celestia-app

FROM ghcr.io/celestiaorg/celestia-node:v0.12.0

USER root

RUN apk update && apk --no-cache add \
    bash \
    jq \
    coreutils \
    curl \
    && mkdir /bridge \
    && chown celestia:celestia /bridge

COPY --from=orchestrator-relayer /bin/blobstream /bin/blobstream

COPY --from=celestia-app /bin/celestia-appd /bin/

EXPOSE 26657 26658 26659 9090

CMD [ "/bin/blobstream" ]
