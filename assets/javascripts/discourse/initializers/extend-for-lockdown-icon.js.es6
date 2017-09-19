import TopicStatus from 'discourse/raw-views/topic-status';

export default {
  name: 'extend-for-lockdown-icon',

  initialize() {

    TopicStatus.reopen({
      statuses: function(){
        const results = this._super();
        if (this.topic.is_locked_down) {
          results.push({
            openTag: 'span',
            closeTag: 'span',
            title: I18n.t('category_lockdown.is_locked_down'),
            icon: 'credit-card'
          });
        }
        return results;
      }.property()
    });
  }
};