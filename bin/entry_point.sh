#!/bin/bash

CONFIG_FILE=_config.yml 
BIB_SOURCE_DIR=_bibliography/papers
RESUME_TEMPLATE_FILE=assets/json/resume.template.json
REPOSITORIES_TEMPLATE_FILE=_pages/repositories.template.md
GALLERY_SOURCE_DIR=_pages/gallery
PEOPLE_SOURCE_DIR=_pages/people
BIB_BUILD_SCRIPT=bin/build_bibliography.rb
REPOSITORIES_PAGE_SCRIPT=bin/generate_repositories_page.rb
GITHUB_METADATA_SCRIPT=bin/fetch_github_metadata.rb
GALLERY_PAGE_SCRIPT=bin/generate_gallery_page.rb
PEOPLE_PAGE_SCRIPT=bin/generate_people_page.rb
RESUME_JSON_SCRIPT=bin/generate_resume_json.rb
CV_LATEX_SCRIPT=bin/generate_cv_latex.rb

# Set environment variables to suppress Sass warnings
export SASS_SILENCE_DEPRECATIONS=*
export SCSS_SILENCE_DEPRECATIONS=*

build_bibliography() {
  ruby "$BIB_BUILD_SCRIPT"
}

generate_resume_json() {
  ruby "$RESUME_JSON_SCRIPT"
}

generate_repositories_page() {
  ruby "$REPOSITORIES_PAGE_SCRIPT"
}

fetch_github_metadata() {
  ruby "$GITHUB_METADATA_SCRIPT"
}

generate_gallery_page() {
  ruby "$GALLERY_PAGE_SCRIPT"
}

generate_people_page() {
  ruby "$PEOPLE_PAGE_SCRIPT"
}

generate_cv_latex() {
  ruby "$CV_LATEX_SCRIPT"
}

start_jekyll() {
  (
    while true; do
      jekyll serve --watch --port=8080 --host=0.0.0.0 --livereload --force_polling
      sleep 1
    done
  ) &
  JEKYLL_PID=$!
}

build_bibliography
generate_repositories_page
fetch_github_metadata
generate_gallery_page
generate_people_page
generate_resume_json
generate_cv_latex
start_jekyll

while true; do

  if changed_path=$(inotifywait -q -r -e modify,move,create,delete --format '%w%f' "$CONFIG_FILE" "$BIB_SOURCE_DIR" "$RESUME_TEMPLATE_FILE" "$REPOSITORIES_TEMPLATE_FILE" "$GALLERY_SOURCE_DIR" "$PEOPLE_SOURCE_DIR"); then
 
    if [ "$changed_path" = "$CONFIG_FILE" ]; then
      echo "Change detected to $CONFIG_FILE, restarting Jekyll"

      kill -KILL "$JEKYLL_PID"

      build_bibliography
      generate_repositories_page
      fetch_github_metadata
      generate_gallery_page
      generate_people_page
      generate_resume_json
      generate_cv_latex
      start_jekyll
    elif [ "$changed_path" = "$REPOSITORIES_TEMPLATE_FILE" ]; then
      echo "Change detected in $REPOSITORIES_TEMPLATE_FILE, regenerating repositories.md"
      generate_repositories_page
      fetch_github_metadata
    elif [[ "$changed_path" == "$GALLERY_SOURCE_DIR/"* ]]; then
      echo "Change detected in $GALLERY_SOURCE_DIR, regenerating gallery.md"
      generate_gallery_page
    elif [[ "$changed_path" == "$PEOPLE_SOURCE_DIR/"* ]]; then
      echo "Change detected in $PEOPLE_SOURCE_DIR, regenerating people.md"
      generate_people_page
    elif [ "$changed_path" = "$RESUME_TEMPLATE_FILE" ]; then
      echo "Change detected in $RESUME_TEMPLATE_FILE, regenerating resume.json"
      generate_resume_json
    else
      echo "Change detected in bibliography sources, rebuilding _papers.bib, repositories.md, gallery.md, people.md, resume.json and cv latex"
      build_bibliography
      generate_repositories_page
      fetch_github_metadata
      generate_gallery_page
      generate_people_page
      generate_resume_json
      generate_cv_latex
    fi

  fi

done
