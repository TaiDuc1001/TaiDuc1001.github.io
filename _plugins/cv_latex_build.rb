# frozen_string_literal: true

require "fileutils"
require "open3"

module CVLatexBuild
  CONFIG_KEY = "cv_latex"

  module_function

  def run(site)
    config = site.config.fetch(CONFIG_KEY, {})
    return unless config.fetch("enabled", true)

    source_rel = config.fetch("source", "assets/latex/cv.tex")
    output_dir_rel = config.fetch("output_dir", "assets/pdf")

    source = File.expand_path(source_rel, site.source)
    output_dir = File.expand_path(output_dir_rel, site.source)

    unless File.file?(source)
      Jekyll.logger.warn("CV LaTeX:", "source not found at #{source_rel}; skipping")
      return
    end

    FileUtils.mkdir_p(output_dir)

    configured_output_name = config["output_name"].to_s.strip
    default_output_name = "#{File.basename(source, File.extname(source))}.pdf"
    pdf_name = configured_output_name.empty? ? default_output_name : configured_output_name
    pdf_path = File.join(output_dir, pdf_name)

    if File.file?(pdf_path) && File.mtime(pdf_path) >= File.mtime(source)
      Jekyll.logger.info("CV LaTeX:", "up to date (#{File.join(output_dir_rel, pdf_name)})")
      return
    end

    tectonic_bin = ENV.fetch("TECTONIC_BIN", "tectonic")
    cmd = [tectonic_bin, "--outdir", output_dir, source]

    begin
      _stdout, stderr, status = Open3.capture3(*cmd)
    rescue Errno::ENOENT
      Jekyll.logger.warn("CV LaTeX:", "'#{tectonic_bin}' not found. Install Tectonic or set TECTONIC_BIN.")
      return
    end

    unless status.success?
      Jekyll.logger.warn("CV LaTeX:", "build failed for #{source_rel}: #{stderr.strip}")
      return
    end

    generated_pdf_name = "#{File.basename(source, File.extname(source))}.pdf"
    generated_pdf_path = File.join(output_dir, generated_pdf_name)
    unless File.file?(generated_pdf_path)
      Jekyll.logger.warn("CV LaTeX:", "expected output not found at #{generated_pdf_path}")
      return
    end

    if generated_pdf_path != pdf_path
      FileUtils.cp(generated_pdf_path, pdf_path)
      FileUtils.rm_f(generated_pdf_path)
    end

    pdf_rel_path = File.join(output_dir_rel, pdf_name)

    Jekyll.logger.info("CV LaTeX:", "compiled #{pdf_rel_path}")
  end
end

Jekyll::Hooks.register :site, :after_reset do |site|
  CVLatexBuild.run(site)
end
