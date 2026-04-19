#!/bin/bash

docker-compose build 
docker-compose run --rm kvin_ubuntu

#first : chmod +x run.sh
#second: ./run.sh