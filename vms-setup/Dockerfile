FROM ubuntu
MAINTAINER Isabella Basso (isabbasso@riseup.net)
# volume mounting won't work with podman in the M1
# refer to https://dalethestirling.github.io/Macos-volumes-with-Podman/
VOLUME /images
COPY ./script-files/* .
COPY ./iso-files/ArchLinuxARM-aarch64-latest.tar.gz .
RUN chmod +x docker_script.sh
RUN apt-get update -y
RUN echo "America/Sao_Paulo" > /etc/timezone
RUN ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
RUN apt-get install -y kpartx dosfstools libarchive-tools gdisk
#ENTRYPOINT ["bash"]
CMD ["./docker_script.sh", "10G", "new_arch"]
