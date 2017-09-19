# name: discourse-category-lockdown
# about: Add a category permission level which allows displaying topic titles only
# version: 0.1
# authors: David Taylor
# url: https://github.com/davidtaylorhq/discourse-category-lockdown

module ::CategoryLockdown
  class NoAccessLocked < StandardError; end
end

after_initialize do
  module ::CategoryLockdown
    def self.is_locked(guardian, topic)
      locked_down = topic.category&.custom_fields&.[]("enable_lockdown") == "true"
      can_access_anyway = guardian.is_admin? # || Has access to the category

      return locked_down && !can_access_anyway
    end
  end

  class ::TopicView
    alias_method :old_check_and_raise_exceptions, :check_and_raise_exceptions

    def check_and_raise_exceptions
      old_check_and_raise_exceptions

      raise ::CategoryLockdown::NoAccessLocked.new if CategoryLockdown.is_locked(@guardian, @topic)
    end

  end

  module ::PostGuardian
    alias_method :old_can_see_post?, :can_see_post?

    def can_see_post?(post)
      return false if !old_can_see_post?(post)
      return false if ::CategoryLockdown.is_locked(self, post.topic)

      true
    end
  end

  class ::TopicListItemSerializer
    attributes :is_locked_down

    def is_locked_down
      ::CategoryLockdown.is_locked(scope, object)
    end

  end

  class ::ApplicationController
    rescue_from ::CategoryLockdown::NoAccessLocked do
      rescue_discourse_actions(:invalid_access, 402, true)
    end
  end

end
