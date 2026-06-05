class BackfillDefaultTransformerProfileContent < ActiveRecord::Migration[8.1]
  # Default profiles created before the default's guidelines and example were
  # moved into the database have blank instructions and no example file. Seed
  # them with the canonical content so existing workspaces match new ones.
  # Only blank defaults are touched, so customized defaults are left alone.
  def up
    TransformerProfile.reset_column_information

    TransformerProfile.where(handle: TransformerProfile::DEFAULT_HANDLE).find_each do |profile|
      next if profile.instructions.present?

      profile.update!(instructions: TransformerProfile::DEFAULT_INSTRUCTIONS)

      next if profile.example_files.attached?

      profile.example_files.attach(
        io: StringIO.new(TransformerProfile::DEFAULT_EXAMPLE_CONTENT),
        filename: TransformerProfile::DEFAULT_EXAMPLE_FILENAME,
        content_type: "text/markdown"
      )
    end
  end

  def down
    # Irreversible content backfill; nothing to undo.
  end
end
