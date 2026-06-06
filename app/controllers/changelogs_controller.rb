# frozen_string_literal: true

class ChangelogsController < ApplicationController
  def show
    @columns = Changelog.week_columns
    @open_entry_slug = params[:version_slug]
  end
end
