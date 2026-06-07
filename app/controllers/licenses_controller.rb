class LicensesController < ApplicationController
  def show
    @groups = ThirdPartyLicenses.groups
  end
end
