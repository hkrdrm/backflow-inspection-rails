class Tenant < Sequel::Model
  plugin :validation_helpers
  plugin :boolean_readers
  # Gives Sequel models the naming/to_key interface form_with needs.
  plugin :active_model
  plugin :timestamps, update_on_create: true

  one_to_many :accounts
  one_to_many :plumbers

  def validate
    super
    validates_presence [ :name, :slug ]
    validates_unique :slug
  end
end
