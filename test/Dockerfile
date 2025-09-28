FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Packages you usually need for Ansible-managed hosts
RUN apt-get update && \
    apt-get install -y openssh-server python3 sudo && \
    rm -rf /var/lib/apt/lists/*

RUN echo "ubuntu:ubuntu" | chpasswd

# Ensure sshd is ready and password auth is ON, root login OFF
RUN mkdir -p /var/run/sshd && \
    printf "PasswordAuthentication yes\nPermitRootLogin no\nUsePAM yes\n" > /etc/ssh/sshd_config.d/ansible.conf

# (Optional) keep sudo requiring a password (more realistic)
# If you want passwordless sudo instead, uncomment the next line:
# RUN echo "%sudo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/01-nopasswd-sudo

EXPOSE 22
CMD ["/usr/sbin/sshd","-D"]
