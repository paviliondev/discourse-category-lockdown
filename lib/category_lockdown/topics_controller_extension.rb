# frozen_string_literal: true
require "request_store"

module ::CategoryLockdown::TopicsControllerExtension
  def show
    ::RequestStore.store[:is_crawler] = use_crawler_layout?
    super
  end
end
