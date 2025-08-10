#!/bin/bash

CONFIG_FILE=_config.yml 

# Set environment variables to suppress Sass warnings
export SASS_SILENCE_DEPRECATIONS=*
export SCSS_SILENCE_DEPRECATIONS=*

/bin/bash -c "rm -f Gemfile.lock && exec jekyll serve --watch --port=8080 --host=0.0.0.0 --livereload --force_polling"&

while true; do

  inotifywait -q -e modify,move,create,delete $CONFIG_FILE

  if [ $? -eq 0 ]; then
 
    echo "Change detected to $CONFIG_FILE, restarting Jekyll"

    jekyll_pid=$(pgrep -f jekyll)
    kill -KILL $jekyll_pid

    /bin/bash -c "rm -f Gemfile.lock && exec jekyll serve --watch --port=8080 --host=0.0.0.0 --livereload --force_polling"&

  fi

done
