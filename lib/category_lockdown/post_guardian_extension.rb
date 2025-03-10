

# Restrict access to posts (e.g. /raw/12/2)
# Also covers notifications, so people cannot 'watch' the topic

module ::CategoryLockdown::PostGuardianExtension
  def can_see_post?(post)
    return super(post) unless SiteSetting.category_lockdown_enabled
    super(post) && !::CategoryLockdown.is_locked(self, post.topic)
  end
end