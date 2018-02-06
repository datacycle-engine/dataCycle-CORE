#!/bin/bash
bundle install
cd test/dummy
rails s -b 0.0.0.0 -p 3000