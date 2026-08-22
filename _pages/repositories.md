---
layout: page
permalink: /repositories/
title: Repositories
description: A list of repositories I have created or contributed to.
nav: true
nav_order: 4

---

<!-- This file is used by bin/generate_repositories_page.rb to generate repositories.md. -->

## GitHub Users

<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% include repository/repo_user.liquid username='aita-lab' %}
  {% include repository/repo_user.liquid username='Lamn17' %}
  {% include repository/repo_user.liquid username='nhut-ngnn' %}
  {% include repository/repo_user.liquid username='TaiDuc1001' %}
</div>

---

## GitHub Repositories

<div class="repositories d-flex flex-wrap flex-md-row flex-column justify-content-between align-items-center">
  {% include repository/repo.liquid repository='aita-lab/FDAL' %}
  {% include repository/repo.liquid repository='Lamn17/DVAL' %}
  {% include repository/repo.liquid repository='nhut-ngnn/AURORA' %}
  {% include repository/repo.liquid repository='nhut-ngnn/CemoBAM' %}
  {% include repository/repo.liquid repository='nhut-ngnn/GloMER' %}
  {% include repository/repo.liquid repository='TaiDuc1001/CorrTie' %}
  {% include repository/repo.liquid repository='TaiDuc1001/DAAL' %}
  {% include repository/repo.liquid repository='TaiDuc1001/R3-CEC' %}
</div>
