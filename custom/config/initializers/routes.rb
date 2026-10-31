# frozen_string_literal: true

custom_routes_path = Rails.root.join('custom/config/routes.rb')
if File.exist?(custom_routes_path)
  routes_path_str = custom_routes_path.to_s
  Rails.application.routes_reloader.paths << routes_path_str unless Rails.application.routes_reloader.paths.include?(routes_path_str)
end
