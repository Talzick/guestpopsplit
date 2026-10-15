# frozen_string_literal: true

module ::GuestCta
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace GuestCta
    config.autoload_paths << File.join(config.root, "lib")
  end
end
