class Account < Sequel::Model
  include Rodauth::Rails.model
  plugin :enum
  plugin :boolean_readers
  plugin :validation_helpers
  # Gives Sequel models the naming/to_key interface form_with needs.
  plugin :active_model
  # Applies the database column defaults to new objects. Without it `role` and
  # `status` are nil at validation time on an unsaved record, and the
  # validations below reject it before the defaults can apply.
  plugin :defaults_setter
  enum :status, unverified: 1, verified: 2, closed: 3

  ROLES = %w[admin plumber].freeze

  # Matches the partial unique index on email, which covers unverified and
  # verified rows only: a closed account's email is free to reuse.
  OPEN_STATUSES = [ :unverified, :verified ].freeze

  many_to_one :tenant

  # Rodauth creates accounts through datasets rather than this model, so these
  # validations govern the super admin panel without touching public signup.
  def validate
    super
    validates_presence :email
    validates_includes ROLES, :role
    # only_if_modified: false because reopen (Task 5) flips status without
    # touching email, and Sequel's default only rechecks uniqueness when the
    # checked column itself changed, which would let the DB's partial unique
    # index raise instead of this validation catching the collision.
    validates_unique(:email, only_if_modified: false) { |ds| ds.where(status: [ 1, 2 ]) } if OPEN_STATUSES.include?(status)
  end
end
