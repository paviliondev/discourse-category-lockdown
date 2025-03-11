# frozen_string_literal: true
module ::CategoryLockdown
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace CategoryLockdown
    config.autoload_paths << File.join(config.root, "lib")
  end

  def self.is_locked(guardian, topic)
    return false if guardian.is_admin?

    locked_down = ["true", "t", true].include?(
      topic.category&.custom_fields&.[]("lockdown_enabled"),
    )
    return false if !locked_down

    allowed_groups = topic.category&.custom_fields&.[]("lockdown_allowed_groups")
    allowed_groups = "" if allowed_groups.nil?
    allowed_groups = allowed_groups.split(",")

    in_allowed_groups = guardian&.user&.groups&.where(name: allowed_groups)&.exists?

    !in_allowed_groups
  end

  class NoAccessLocked < StandardError
  end
end
