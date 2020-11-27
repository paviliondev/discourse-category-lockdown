import Category from "discourse/models/category";
import { alias } from "@ember/object/computed";

export default {
  name: "extend-category-for-lockdown",
  before: "inject-discourse-objects",
  initialize() {
    Category.reopen({
      lockdown_enabled: Ember.computed(
        "custom_fields.lockdown_enabled",
        {
          get(fieldName) {
            return Ember.get(this.custom_fields, fieldName) === "true";
          },
        }
      ),
      redirect_url: alias('custom_fields.redirect_url'),
    });
  },
};
