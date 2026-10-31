# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Custom Layer Autoloader', type: :request do
  describe 'Zeitwerk dynamic autoloading' do
    it 'autoloads classes under Custom:: namespace without explicit requires' do
      expect(defined?(Custom::SmokeTestService)).to eq('constant')
      expect(Custom::SmokeTestService.healthy?).to be true
      expect(Custom::SmokeTestService.layer_info[:status]).to eq('active')
    end

    it 'registers custom directories into Rails Zeitwerk autoloader' do
      registered_dirs = Rails.autoloaders.main.dirs
      custom_services_dir = Rails.root.join('custom/app/services').to_s

      expect(registered_dirs).to include(custom_services_dir)
    end

    it 'ensures core config/application.rb is clean and untouched' do
      application_rb = File.read(Rails.root.join('config/application.rb'))
      expect(application_rb).not_to include('custom/app')
    end
  end
end
