# name: discourse-category-lockdown
# about: Set all topics in a category to redirect, unless part of a specified group
# version: 0.1
# authors: David Taylor
# url: https://github.com/davidtaylorhq/discourse-category-lockdown

enabled_site_setting :category_lockdown_enabled

register_asset 'stylesheets/lockdown.scss'

after_initialize do

  module ::CategoryLockdown
    def self.is_locked(guardian, topic)
      return false if guardian.is_admin?

      locked_down = topic.category&.custom_fields&.[]("lockdown_enabled") == "true"
      return false if !locked_down

      allowed_groups = topic.category&.custom_fields&.[]("lockdown_allowed_groups")
      allowed_groups = allowed_groups.split(',')

      in_allowed_groups = guardian.user&.groups.where(name: allowed_groups).exists?

      return !in_allowed_groups
    end

    class NoAccessLocked < StandardError; end
  end

  # Restrict topic views, including RSS/Print/Search-engine
  class ::TopicView
    alias_method :old_check_and_raise_exceptions, :check_and_raise_exceptions

    def check_and_raise_exceptions
      old_check_and_raise_exceptions

      if SiteSetting.category_lockdown_enabled
        raise ::CategoryLockdown::NoAccessLocked.new if CategoryLockdown.is_locked(@guardian, @topic)
      end
    end
  end
  TopicList.preloaded_custom_fields << "lockdown_enabled"
  TopicList.preloaded_custom_fields << "lockdown_allowed_groups"

  class ::ApplicationController
    rescue_from ::CategoryLockdown::NoAccessLocked do
      rescue_discourse_actions(:invalid_access, 402, true)
    end
  end

  # Restrict access to posts (e.g. /raw/12/2)
  # Also covers notifications, so people cannot 'watch' the topic
  module ::PostGuardian
    alias_method :old_can_see_post?, :can_see_post?

    def can_see_post?(post)
      return old_can_see_post?(post) unless SiteSetting.category_lockdown_enabled

      return false if !old_can_see_post?(post)
      return false if ::CategoryLockdown.is_locked(self, post.topic)

      true
    end
  end

  # Add a boolean to the topic list serializer
  # So that we can show an icon next to each topic
  class ::TopicListItemSerializer
    attributes :is_locked_down

    def is_locked_down
      ::CategoryLockdown.is_locked(scope, object)
    end

    def include_is_locked_down?
      SiteSetting.category_lockdown_enabled
    end

  end

end
