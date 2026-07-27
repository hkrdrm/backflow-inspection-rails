class Comic < Sequel::Model
  one_to_many :comic_issues
end
