# frozen_string_literal: true
require "request_store"

module CategoryLockdown::TopicViewExtension
  def check_and_raise_exceptions(skip_staff_action)
    super
    return if ::RequestStore.store[:is_crawler] && SiteSetting.category_lockdown_allow_crawlers
    if SiteSetting.category_lockdown_enabled && CategoryLockdown.is_locked(@guardian, @topic)
      raise ::CategoryLockdown::NoAccessLocked.new
    end
  end
end
