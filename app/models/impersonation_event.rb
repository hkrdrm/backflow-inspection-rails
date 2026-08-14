# One row per non-GET request made while impersonating, including requests
# that failed validation: an attempted write is exactly what an audit trail
# should show.
class ImpersonationEvent < Sequel::Model
  many_to_one :impersonation_session
end
