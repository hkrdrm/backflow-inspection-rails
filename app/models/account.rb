class Account < Sequel::Model
  include Rodauth::Rails.model
  plugin :enum
  enum :status, unverified: 1, verified: 2, closed: 3

  many_to_one :company
end
