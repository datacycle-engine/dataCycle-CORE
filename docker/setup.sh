#!/bin/bash
#unset BUNDLE_PATH
#unset BUNDLE_BIN
gem install bundler
bundle update
bundle install

cd test/dummy

# RUBYOPT="--jit-verbose=1" rails s -b 0.0.0.0 -p 3000
#rails s -b 0.0.0.0 -p 3000
#export RUBYOPT="-W:no-deprecated -W:no-experimental"
RUBYOPT="-W:no-deprecated -W:no-experimental" rails s -b 0.0.0.0 -p 3000
