FROM debian:latest

RUN apt-get update \
    && apt-get install -y curl unzip ssh \
    && apt clean

WORKDIR /tmp

# 安装aws cli
# https://docs.aws.amazon.com/zh_cn/cli/latest/userguide/getting-started-install.html
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && aws --version \
    && rm -rf ./awscliv2.zip

# 安装Session Manager
# https://docs.aws.amazon.com/zh_cn/systems-manager/latest/userguide/install-plugin-debian-and-ubuntu.html
RUN curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" \
    && dpkg -i session-manager-plugin.deb \
    && session-manager-plugin \
    && rm -rf ./session-manager-plugin.deb

WORKDIR /scripts

COPY scripts/* .

RUN chmod +x ./connect_jump_server.sh

CMD ["/bin/bash", "-c", "/scripts/run.sh"]