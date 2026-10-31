# frozen_string_literal: true

# =============================================================================
# Custom Layer Autoloader (Zeitwerk Integration)
# =============================================================================
# This initializer dynamically registers the `custom/` directory into the Rails
# Zeitwerk autoloader. All proprietary Flowbuilder and URA classes, models,
# controllers, services, jobs, and listeners reside in `custom/` to ensure zero
# merge conflicts when upgrading upstream Chatwoot core releases.
#
# DO NOT remove or modify core config/application.rb; this initializer executes
# early (prefixed with 00_) during the Rails boot cycle.
# =============================================================================

custom_app_path = Rails.root.join('custom/app')
custom_lib_path = Rails.root.join('custom/lib')

if Dir.exist?(custom_app_path)
  Dir.glob(custom_app_path.join('*')).select { |entry| File.directory?(entry) }.each do |dir|
    dir_str = dir.to_s
    Rails.autoloaders.main.push_dir(dir_str) unless Rails.autoloaders.main.dirs.include?(dir_str)
  end
end

if Dir.exist?(custom_lib_path)
  custom_lib_str = custom_lib_path.to_s
  Rails.autoloaders.main.push_dir(custom_lib_str) unless Rails.autoloaders.main.dirs.include?(custom_lib_str)
end
