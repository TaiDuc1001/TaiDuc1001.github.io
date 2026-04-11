# frozen_string_literal: true

module GalleryPeopleAutobuild
  GALLERY_SOURCE_RELATIVE_PATH = "_pages/gallery"
  PEOPLE_SOURCE_RELATIVE_PATH = "_pages/people"
  GALLERY_OUTPUT_RELATIVE_PATH = "_pages/gallery.md"
  PEOPLE_OUTPUT_RELATIVE_PATH = "_pages/people.md"
  GALLERY_SCRIPT_RELATIVE_PATH = "bin/generate_gallery_page.rb"
  PEOPLE_SCRIPT_RELATIVE_PATH = "bin/generate_people_page.rb"

  def self.run_generator(script_path, source_path, output_path, label)
    return unless File.exist?(script_path)
    return unless Dir.exist?(source_path)

    success = system("ruby", script_path, source_path, output_path)
    return if success

    Jekyll.logger.warn("gallery-people-autobuild:", "failed to regenerate #{label}")
  end

  def self.build(site)
    root = site.source

    run_generator(
      File.join(root, GALLERY_SCRIPT_RELATIVE_PATH),
      File.join(root, GALLERY_SOURCE_RELATIVE_PATH),
      File.join(root, GALLERY_OUTPUT_RELATIVE_PATH),
      "_pages/gallery.md"
    )

    run_generator(
      File.join(root, PEOPLE_SCRIPT_RELATIVE_PATH),
      File.join(root, PEOPLE_SOURCE_RELATIVE_PATH),
      File.join(root, PEOPLE_OUTPUT_RELATIVE_PATH),
      "_pages/people.md"
    )
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  GalleryPeopleAutobuild.build(site)
end
