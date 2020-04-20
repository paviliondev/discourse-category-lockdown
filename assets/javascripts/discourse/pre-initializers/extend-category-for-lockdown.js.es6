import Category from 'discourse/models/category';
import { alias } from "@ember/object/computed";

export default {
  name: 'extend-category-for-lockdown',
  before: 'inject-discourse-objects',
  initialize() {
    Category.reopen({
      lockdown_enabled: alias('custom_fields.lockdown_enabled'),
      redirect_url: alias('custom_fields.redirect_url'),
    });
  }
};
