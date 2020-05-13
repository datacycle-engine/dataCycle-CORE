#!/bin/bash
# unset BUNDLE_PATH
# unset BUNDLE_BIN
echo "$(ip route|awk '/default/ { print $3 }') dockerhost" >> /etc/hosts
gem install bundler
# bundle update
bundle install
cd test/dummy
# RUBYOPT="--jit-verbose=1" rails s -b 0.0.0.0 -p 3000
rails s -b 0.0.0.0 -p 3000
