#!/usr/bin/env bash

### Configure proxy settings instead of system environment variables that are lost on Jenkins.

export http_proxy="http://proxy.example.com:8080"
export https_proxy="http://proxy.example.com:8080"
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"
export no_proxy=".example.com,127.0.0.1,localhost"
export NO_PROXY=".example.com,127.0.0.1,localhost"
