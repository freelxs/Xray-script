FROM ubuntu:jammy

# Import Cloudflare's apt key only when its fingerprint matches the published key,
# then install the signed jammy package. The package version still follows that repo.
RUN apt-get update && \
    apt-get install -y --no-install-recommends socat ca-certificates curl gpg && \
    curl -fsSL --proto '=https' --tlsv1.2 --retry 3 \
        -o /tmp/cloudflare-warp.gpg https://pkg.cloudflareclient.com/pubkey.gpg && \
    test "$(gpg --show-keys --with-colons /tmp/cloudflare-warp.gpg | awk -F: '/^fpr:/ {print $10; exit}')" = "C068A2B5771775193CBE1F2F6E2DD2174FA1C3BA" && \
    gpg --dearmor < /tmp/cloudflare-warp.gpg > /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg && \
    rm -f /tmp/cloudflare-warp.gpg && \
    printf 'deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ jammy main\n' \
        > /etc/apt/sources.list.d/cloudflare-client.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends cloudflare-warp && \
    apt-get purge -y curl gpg && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY startup.sh /bin/startup.sh
RUN chmod a+x /bin/startup.sh
ENTRYPOINT [ "/bin/startup.sh" ]
