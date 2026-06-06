class ErrorsController < ApplicationController
  def not_found
    render "errors/not_found", status: :not_found, formats: :html
  end
end
