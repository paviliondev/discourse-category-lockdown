# frozen_string_literal: true
# name: discourse-category-lockdown
# about: Set all topics in a category to redirect, unless part of a specified group
# version: 1.2.0
# authors: Pavilion
# meta_topic_id: 70649
# url: https://github.com/paviliondev/discourse-category-lockdown

enabled_site_setting :category_lockdown_enabled
register_asset "stylesheets/lockdown.scss"

module ::CategoryLockdown
  PLUGIN_NAME = "category-lockdown"
end

require_relative "lib/category_lockdown/engine"

after_initialize do
  register_html_builder("server:before-head-close-crawler") do |controller|
    ::CategoryLockdown::CrawlerHtmlBuilder.perform(controller)
  end

  rescue_from(::CategoryLockdown::NoAccessLocked) do
    opts = { include_ember: true }
    topic_id = params["topic_id"] || params["id"]
    topic_id ||= params["topic"] # if coming from discourse-docs plugin
    topic = Topic.find(topic_id.to_i) if topic_id
    response = { error: "Payment Required" }
    response[:redirect_url] = topic.category.custom_fields["redirect_url"] if topic
    response[:redirect_url] ||= SiteSetting.category_lockdown_redirect_url
    if request.format.json?
      render_json_dump(response, status: 402)
    else
      redirect_to path(response[:redirect_url]), allow_other_host: true
    end
  end

  ::TopicsController.prepend ::CategoryLockdown::TopicsControllerExtension
  ::TopicView.prepend ::CategoryLockdown::TopicViewExtension
  ::Guardian.prepend ::CategoryLockdown::PostGuardianExtension

  register_category_custom_field_type("redirect_url", :string)
  Site.preloaded_category_custom_fields << "redirect_url"
  if defined?(register_category_list_preloaded_category_custom_fields)
    register_category_list_preloaded_category_custom_fields("redirect_url")
  end
  ::TopicList.preloaded_custom_fields << "lockdown_enabled"
  ::TopicList.preloaded_custom_fields << "lockdown_allowed_groups"

  add_to_serializer(
    :basic_category,
    :redirect_url,
    include_condition: -> { SiteSetting.category_lockdown_enabled },
  ) { object.custom_fields["redirect_url"] }

  add_to_serializer(
    :topic_list_item,
    :is_locked_down,
    include_condition: -> { SiteSetting.category_lockdown_enabled },
  ) { ::CategoryLockdown.is_locked(scope, object) }
end
