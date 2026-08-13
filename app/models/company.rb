class Company < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true

  one_to_many :accounts

  def validate
    super
    validates_presence [ :name, :slug ]
    validates_unique :slug
  end
end
