#!/bin/bash

yum remove -y docker;
yum remove -y docker-client;
yum remove -y docker-client-latest;
yum remove -y docker-common;
yum remove -y docker-latest;
yum remove -y docker-latest-logrotate;
yum remove -y docker-logrotate;
yum remove -y docker-selinux;
yum remove -y docker-engine-selinux;
yum remove -y docker-engine;
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo;
yum install -y docker-ce;
systemctl start docker;
