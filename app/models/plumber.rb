class Plumber < Sequel::Model
  plugin :validation_helpers
  plugin :boolean_readers
  plugin :active_model
  plugin :timestamps, update_on_create: true
  # Applies the database column defaults to new objects. Without it,
  # cert_status is nil at validation time on an unsaved record and
  # validates_includes below rejects it before the default can apply.
  plugin :defaults_setter

  CERT_STATUSES = %w[pending verified expired revoked].freeze

  many_to_one :tenant
  many_to_one :account

  def validate
    super
    validates_presence [ :tenant_id, :name, :cert_number ]
    validates_includes CERT_STATUSES, :cert_status
    validates_unique [ :tenant_id, :cert_number ]
  end
end
