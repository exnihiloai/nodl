class ChangeTransformerProfileInstructionsNull < ActiveRecord::Migration[8.1]
  # The model validates `instructions` presence, but the column was nullable.
  # Back the validation with a NOT NULL constraint. Uses the strong_migrations
  # safe pattern (validate a NOT NULL check constraint first, so SET NOT NULL is
  # fast and doesn't take a long ACCESS EXCLUSIVE lock on large tables).
  #
  # disable_ddl_transaction! so validate_check_constraint runs outside a
  # transaction (it would otherwise block writes while validating).
  disable_ddl_transaction!

  def up
    add_check_constraint :transformer_profiles, "instructions IS NOT NULL",
                         name: "transformer_profiles_instructions_null", validate: false
    validate_check_constraint :transformer_profiles, name: "transformer_profiles_instructions_null"
    change_column_null :transformer_profiles, :instructions, false
    remove_check_constraint :transformer_profiles, name: "transformer_profiles_instructions_null"
  end

  def down
    change_column_null :transformer_profiles, :instructions, true
  end
end
