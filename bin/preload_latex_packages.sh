#!/usr/bin/env bash

set -euo pipefail

tectonic_bin="${TECTONIC_BIN:-tectonic}"
if ! command -v "$tectonic_bin" >/dev/null 2>&1; then
  echo "tectonic not found in PATH. Install it before preloading LaTeX packages." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat > "${tmp_dir}/ref.bib" <<'EOF'
@article{warmup_ref,
  author  = {Warmup, Tectonic},
  title   = {Warmup bibliography entry},
  journal = {Warmup Journal},
  year    = {2026},
  keyword = {J}
}
EOF

cat > "${tmp_dir}/warmup.tex" <<'EOF'
\documentclass[11pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage[
  backend=bibtex,
  maxnames=20,
  style=nature,
  sorting=ydnt,
  defernumbers=true
]{biblatex}
\addbibresource{ref.bib}
\usepackage{longtable}
\usepackage{bookmark}
\usepackage{fontawesome}
\usepackage{ragged2e}
\usepackage{soul}
\usepackage{kpfonts}
\usepackage[T1]{fontenc}
\usepackage{xcolor}
\usepackage{hyperref}

\begin{document}
\definecolor{cornflowerblue}{HTML}{6495ed}
\hypersetup{
  colorlinks=true,
  breaklinks=true,
  linkcolor=cornflowerblue,
  urlcolor=cornflowerblue,
  anchorcolor=cornflowerblue,
  citecolor=cornflowerblue
}
\RaggedRight
\begin{longtable}[l]{@{}p{.125\textwidth} p{0.875\textwidth}}
  2026 & Warmup line \\
\end{longtable}
\nocite{*}
\printbibliography[heading=none]
\end{document}
EOF

"$tectonic_bin" --reruns 0 --outdir "$tmp_dir" "${tmp_dir}/warmup.tex" >/dev/null

if [[ ! -f "${tmp_dir}/warmup.pdf" ]]; then
  echo "Failed to generate warmup.pdf while preloading LaTeX packages." >&2
  exit 1
fi

echo "LaTeX package warmup completed."
