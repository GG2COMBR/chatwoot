# frozen_string_literal: true

# Loads GG2 Flowbuilder custom rake tasks
Dir.glob(Rails.root.join('custom/lib/tasks/**/*.rake')).each { |f| load f }
