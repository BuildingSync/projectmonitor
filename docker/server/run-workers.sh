#!/usr/bin/env bash

echo "Calling run-workers"

echo "Waiting for mysql to start"
/usr/local/wait-for-it.sh --strict -t 0 db:3306
echo "Waiting for web to start"
/usr/local/wait-for-it.sh --strict -t 0 127.0.0.1:80

echo "Running workers..."
bundle exec rake start_workers_foreground[2]