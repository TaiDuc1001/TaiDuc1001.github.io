# frozen_string_literal: true

module BibliographyAutobuild
  SOURCE_RELATIVE_PATH = "_bibliography/papers"
  OUTPUT_RELATIVE_PATH = "_bibliography/_papers.bib"
  SCRIPT_RELATIVE_PATH = "bin/build_bibliography.rb"

  def self.build(site)
    script = File.join(site.source, SCRIPT_RELATIVE_PATH)
    source = File.join(site.source, SOURCE_RELATIVE_PATH)
    output = File.join(site.source, OUTPUT_RELATIVE_PATH)

    return unless File.exist?(script)
    return unless Dir.exist?(source)

    success = system("ruby", script, source, output)
    unless success
      Jekyll.logger.warn("bibliography-autobuild:", "failed to regenerate _papers.bib")
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  BibliographyAutobuild.build(site)
end
