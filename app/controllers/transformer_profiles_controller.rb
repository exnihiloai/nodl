class TransformerProfilesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_workspace!
  before_action :set_transformer_profile, only: %i[show edit update destroy remove_example_file]

  def show
    # Show the actual text of each example so users can see what a good result
    # looks like and model their own format on it.
    @example_previews = @transformer_profile.example_files.map do |file|
      [ file, DocumentTextExtractor.extract(file) ]
    end
  end

  def new
    if @workspace.format_limit_reached?
      result = @workspace.entitlement_for(:custom_formats)
      redirect_to dashboard_path, alert: t("dashboard.limits.formats_reached", limit: result.limit)
      return
    end

    @transformer_profile = @workspace.transformer_profiles.new
  end

  def create
    @transformer_profile = @workspace.transformer_profiles.new(profile_attributes)
    @transformer_profile.handle = unique_handle_for(@transformer_profile.name)
    attach_example_files(@transformer_profile)

    if @transformer_profile.save
      redirect_to dashboard_path, notice: t("flash.transformer_profiles.created", name: @transformer_profile.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @transformer_profile.assign_attributes(profile_attributes)
    attach_example_files(@transformer_profile)

    if @transformer_profile.save
      redirect_to dashboard_path, notice: t("flash.transformer_profiles.updated", name: @transformer_profile.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @transformer_profile.default?
      return redirect_to dashboard_path, alert: t("flash.transformer_profiles.default_undeletable")
    end

    @transformer_profile.destroy
    redirect_to dashboard_path, notice: t("flash.transformer_profiles.deleted", name: @transformer_profile.name)
  end

  def remove_example_file
    @removed_attachment = @transformer_profile.example_files.attachments.find(params[:attachment_id])
    @removed_attachment.purge

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to edit_transformer_profile_path(@transformer_profile), notice: t("flash.transformer_profiles.example_removed") }
    end
  end

  private

  def set_transformer_profile
    @transformer_profile = @workspace.transformer_profiles.find(params[:id])
  end

  def profile_attributes
    params.require(:transformer_profile).permit(:name, :instructions)
  end

  # Attach newly uploaded example documents without replacing the ones already
  # stored (Rails 8 replaces on bulk assignment, which would purge them).
  def attach_example_files(profile)
    uploads = Array(params.dig(:transformer_profile, :example_files)).reject(&:blank?)
    profile.example_files.attach(uploads) if uploads.any?

    attach_pasted_text(profile)
  end

  # Turns text the user pasted into the form into a plain-text example document,
  # stored exactly like an uploaded file.
  def attach_pasted_text(profile)
    text = params.dig(:transformer_profile, :example_text).to_s
    return if text.strip.blank?

    profile.example_files.attach(
      io: StringIO.new(text),
      filename: pasted_example_filename(text),
      content_type: "text/plain"
    )
  end

  # Names the pasted example after its first line so it is recognizable in the
  # list, falling back to a generic name.
  def pasted_example_filename(text)
    title = text.strip.lines.first.to_s.gsub(%r{[/\\]}, " ").squish
    title = "Pasted example" if title.blank?
    "#{title.truncate(60, omission: '')}.txt"
  end

  # Custom formats are addressed by a URL-safe handle derived from the name.
  # Keep it unique within the workspace by appending a numeric suffix on clashes.
  def unique_handle_for(name)
    base = name.to_s.parameterize.presence || "format"
    candidate = base
    suffix = 2

    while @workspace.transformer_profiles.exists?(handle: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end
end
