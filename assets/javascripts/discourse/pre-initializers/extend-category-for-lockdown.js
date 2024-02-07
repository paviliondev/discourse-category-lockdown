import Category from "discourse/models/category";
import { alias } from "@ember/object/computed";
import { computed } from "@ember/object";

export default {
  name: "extend-category-for-lockdown",
  before: "inject-discourse-objects",
  initialize() {
    Category.reopen({
      lockdown_enabled: computed(
        "custom_fields.lockdown_enabled",
        {
          get() {
            return this?.custom_fields?.lockdown_enabled === "true";
          },
        }
      ),
      redirect_url: alias('custom_fields.redirect_url'),
    });
  },
};
