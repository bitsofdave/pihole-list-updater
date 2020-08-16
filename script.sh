#!/bin/bash

ruby /app/ruby.rb

docker exec pihole pihole -g
