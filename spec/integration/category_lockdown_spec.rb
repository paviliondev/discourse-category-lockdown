# frozen_string_literal: true
require "rails_helper"

RSpec.describe "CategoryLockdown", type: :request do
  before { SiteSetting.category_lockdown_enabled = true }

  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }
  let!(:post) { Fabricate(:post, topic: topic) }
  let(:allowed_group) { Fabricate(:group) }
  let(:allowed_user) { Fabricate(:user, groups: [allowed_group]) }
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  it "doesn't affect access to normal categories" do
    get "/t/#{topic.slug}/#{topic.id}"
    expect(response.code).to eq("200")
  end

  context "with category locked down" do
    before do
      category.custom_fields["lockdown_enabled"] = "t"
      category.custom_fields["lockdown_allowed_groups"] = allowed_group.name
      category.save!
    end

    it "doesn't affect access if disabled" do
      SiteSetting.category_lockdown_enabled = false
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("200")
    end

    it "doesn't allow public access to the topic url" do
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response).to redirect_to("#{Discourse.base_url}/")
    end

    it "doesn't allow public access to the print url" do
      get "/t/#{topic.slug}/#{topic.id}/print"
      expect(response).to redirect_to("#{Discourse.base_url}/")
    end

    it "doesn't allow public access to the rss url" do
      get "/t/#{topic.slug}/#{topic.id}.rss"
      expect(response).to redirect_to("#{Discourse.base_url}/")
    end

    it "doesn't allow public access to the raw url" do
      get "/raw/#{topic.id}/1"
      expect(response.code).to eq("404")
    end

    it "doesn't allow any user access" do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response).to redirect_to("#{Discourse.base_url}/")
    end

    it "allows admins access" do
      sign_in(admin)
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("200")
    end

    it "allows group members access" do
      sign_in(allowed_user)
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("200")
    end

    context "with a redirect url" do
      before do
        category.custom_fields["redirect_url"] = "https://google.com"
        category.save_custom_fields(true)
      end

      it "redirects to an external url" do
        get "/t/#{topic.slug}/#{topic.id}"
        expect(response).to redirect_to("https://google.com")
      end
    end

    context "with a crawler request" do
      it "doesn't allow access" do
        get "/t/#{topic.slug}/#{topic.id}", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response).to redirect_to("#{Discourse.base_url}/")
      end

      context "with category_lockdown_allow_crawlers enabled" do
        before { SiteSetting.category_lockdown_allow_crawlers = true }

        it "injects the right markup" do
          get "/t/#{topic.slug}/#{topic.id}", headers: { "HTTP_USER_AGENT" => "Googlebot" }
          expect(response.body).to include(
            "<script type=\"application/ld+json\">{\"@context\":\"http://schema.org\",\"@type\":\"CreativeWork\",\"name\":\"#{topic&.title}\",\"isAccessibleForFree\":\"False\",\"hasPart\":{\"@type\":\"DiscussionForumPosting\",\"isAccessibleForFree\":\"False\",\"cssSelector\":\"body\"}}</script>",
          )
          expect(response.body).to include("<meta name=\"robots\" content=\"noarchive\">")
        end
      end
    end
  end
end
