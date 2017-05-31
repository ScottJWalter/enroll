class FinancialAssistance::DeductionsController < ApplicationController
  include UIHelpers::WorkflowController

  before_filter :find_applicant


  def edit
  	@model = @applicant.deductions.find(params[:id])
  	load_steps
  	current_step
  end

  private
  def find_applicant
  	@applicant = #Query to find applicant here
  end
end