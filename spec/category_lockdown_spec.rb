# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'CategoryLockdown', type: :request do
  before do
    SiteSetting.category_lockdown_enabled = true
  end

  let(:category) { Fabricate(:category) }
  let(:author) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic, category: category, user: author) }
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
      category.custom_fields["lockdown_enabled"] = "true"
      category.custom_fields["lockdown_allowed_groups"] = allowed_group.name
      category.save!
    end

    it "doesn't affect access if disabled" do
      SiteSetting.category_lockdown_enabled = false
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("200")
    end

    it "doesn't allow public access" do
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("301")

      get "/t/#{topic.slug}/#{topic.id}/print"
      expect(response.code).to eq("301")

      get "/t/#{topic.slug}/#{topic.id}.rss"
      expect(response.code).to eq("404")

      get "/raw/#{topic.id}/1"
      expect(response.code).to eq("404")
    end

    it "doesn't allow any user access" do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq("301")
    end
    it "doesn't allow author access" do
      sign_in(author)
      get "/t/#{topic.slug}/#{topic.id}"
      expect(response.code).to eq('301')
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
    context "with allow_authors_in_locked_categories enabled" do
      before { SiteSetting.allow_authors_in_locked_categories = true }

      it 'allows authors access to their own topics' do
        sign_in(author) # user is the author of the topic
        get "/t/#{topic.slug}/#{topic.id}"
        expect(response.code).to eq("200")
      end
    end
  end
end
