class ComicsController < ApplicationController
  def index
    @comics = Comic.all
    @issues = Issue.all
  end
end
