#!/bin/bash

CONFIG_FILE=_config.yml 
BIB_SOURCE_DIR=_bibliography/papers
BIB_BUILD_SCRIPT=bin/build_bibliography.rb

# Set environment variables to suppress Sass warnings
export SASS_SILENCE_DEPRECATIONS=*
export SCSS_SILENCE_DEPRECATIONS=*

build_bibliography() {
  ruby "$BIB_BUILD_SCRIPT"
}

start_jekyll() {
  /bin/bash -c "rm -f Gemfile.lock && exec jekyll serve --watch --port=8080 --host=0.0.0.0 --livereload --force_polling"&
  JEKYLL_PID=$!
}

build_bibliography
start_jekyll

while true; do

  if changed_path=$(inotifywait -q -r -e modify,move,create,delete --format '%w%f' "$CONFIG_FILE" "$BIB_SOURCE_DIR"); then
 
    if [ "$changed_path" = "$CONFIG_FILE" ]; then
      echo "Change detected to $CONFIG_FILE, restarting Jekyll"

      kill -KILL "$JEKYLL_PID"

      build_bibliography
      start_jekyll
    else
      echo "Change detected in bibliography sources, rebuilding _papers.bib"
      build_bibliography
    fi

  fi

done
