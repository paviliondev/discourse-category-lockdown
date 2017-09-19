import property from 'ember-addons/ember-computed-decorators';
import Category from 'discourse/models/category';

export default {
  name: 'extend-category-for-lockdown',
  before: 'inject-discourse-objects',
  initialize() {

    Category.reopen({

      @property('custom_fields.lockdown_enabled')
      lockdown_enabled: {
        get(value) {
          return value === "true";
        },
        set(value) {
          const saveVal = value ? "true" : "false";
          this.set("custom_fields.lockdown_enabled", saveVal);
          return value;
        }
      }

    });
  }
};
