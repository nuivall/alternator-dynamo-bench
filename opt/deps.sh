#!/bin/bash

apt update
apt install -y python2
ln -s /usr/bin/python2 /usr/bin/python
apt install -y default-jre

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo apt install unzip
unzip -o awscliv2.zip
sudo ./aws/install --update
