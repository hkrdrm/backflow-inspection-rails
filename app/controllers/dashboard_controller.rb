class DashboardController < ApplicationController
  def index
  end

  def new_issue
  end

  def create_issue
    @issue = Issue.create(
      name: params[:name], description: params[:description],
      issue_number: params[:issue_number], comic_id: params[:comic_id],
    )

    @issue.save_image(params[:image])
  end
end
