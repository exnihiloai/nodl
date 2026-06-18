class TrialFormatWall
  def initialize(workspace)
    @workspace = workspace
  end

  def formats
    workspace.transformer_profiles.active.where(default: false).order(:handle)
  end

  def formats_count
    formats.count
  end

  private

  attr_reader :workspace
end
