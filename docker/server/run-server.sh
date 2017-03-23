#!/usr/bin/env bash

echo "Calling run-server"

echo "Waiting for mysql to start"
/usr/local/wait-for-it.sh --strict -t 0 db:3306

echo "Calling bundle exec rake db:migrate"
cd /opt/buildingsync/dashboard && bundle exec rake db:migrate

echo "Updating crontab"
whenever --update-crontab

# last command needs to be the nginx. Nginx runs in the foreground.
echo "Running nginx..."
/opt/nginx/sbin/nginx