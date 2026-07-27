# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :comics do
      primary_key :id
      String      :name
      String      :artist_name
      String      :description
      Date        :release_date
      String      :poster_url
      DateTime    :created_at
      DateTime    :updated_at
      DateTime    :deleted_at
    end

    create_table :comic_issues do
      primary_key :id
      foreign_key :comic_id, :comics
      String      :name
      String      :description
      String      :issue_number
      Date        :issue_date
      String      :cover_url
      String      :image_url
      Integer     :grid_rows_x
      Integer     :grid_rows_y
      DateTime    :created_at
      DateTime    :updated_at
      DateTime    :deleted_at
    end
  end
end
