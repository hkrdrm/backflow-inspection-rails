# What the platform does with each module defined in TenantModules::Registry:
#
#   active    can be added to tenants; tenants who have it use it
#   disabled  can't be added; tenants who have it lose access (assignment and
#             data are kept, and come back when it's active again)
#   planned   can't be added; shown to tenants as "Coming soon"
#
# A registered module with no row counts as disabled, so a module shipped in
# code stays off everywhere until a super admin activates it.
class PlatformModule < Sequel::Model
  STATUSES = %w[active disabled planned].freeze
  DEFAULT_STATUS = "disabled".freeze

  # Raised when adding a module to a tenant while it isn't active platform-wide.
  class NotActive < StandardError; end

  def self.status_for(key)
    where(module_key: key.to_s).get(:status) || DEFAULT_STATUS
  end

  def self.statuses
    TenantModules::Registry.keys.index_with { DEFAULT_STATUS }.merge(select_hash(:module_key, :status).slice(*TenantModules::Registry.keys))
  end

  def self.active_keys
    where(status: "active", module_key: TenantModules::Registry.keys).select_map(:module_key)
  end

  def self.planned_modules
    keys = where(status: "planned").select_map(:module_key)
    TenantModules::Registry.all.select { |definition| keys.include?(definition.key) }
  end

  # Returns true if the status changed. The row and its audit event are written
  # together or not at all.
  def self.set_status!(key, status, by:)
    definition = TenantModules::Registry.find(key) or raise ArgumentError, "unknown module: #{key}"
    raise ArgumentError, "unknown status: #{status}" unless STATUSES.include?(status)

    db.transaction do
      from = status_for(definition.key)
      return false if from == status

      now = Time.current
      dataset.insert_conflict(target: :module_key, update: { status: status, updated_at: now, updated_by_account_id: by&.id })
             .insert(module_key: definition.key, status: status, updated_at: now, updated_by_account_id: by&.id)
      PlatformModuleEvent.create(module_key: definition.key, from_status: from, to_status: status,
                                 account_id: by&.id, created_at: now)
      true
    end
  end
end
