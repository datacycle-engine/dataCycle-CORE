#!/bin/bash
gem install bundler
bundle install
cd test/dummy
#RUBYOPT="--jit-verbose=1" rails s -b 0.0.0.0 -p 3000
rails s -b 0.0.0.0 -p 3000
