# One row per impersonation. Append-only apart from stamping `ended_at`:
# nothing in the app updates or deletes these rows, because an audit trail an
# operator can edit is not an audit trail.
class ImpersonationSession < Sequel::Model
  many_to_one :impersonator, class: :Account, key: :impersonator_account_id
  many_to_one :impersonated, class: :Account, key: :impersonated_account_id
  many_to_one :tenant
  one_to_many :impersonation_events

  def live?
    ended_at.nil?
  end
end
