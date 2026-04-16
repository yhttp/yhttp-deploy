#! /usr/bin/env bash


cd $(mktemp -d)
git clone https://github.com/yhttp/yhttp-deploy.git
cd yhttp-deploy
make install
