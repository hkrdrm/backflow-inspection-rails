module TenantModules
  # Every module that exists. A module exists once there is code for it, so this
  # list lives in code, not the database: adding a module means adding a
  # definition here plus its namespaced code (controllers, models, views under
  # its key) — no migration. Which tenants have which module is data, in
  # `tenant_modules`.
  #
  # Every module is general: none is built for a single client, and no module
  # code may branch on which tenant it is serving.
  module Registry
    DEFINITIONS = [
      Definition.new(
        key: "backflow",
        name: "Backflow Inspections",
        description: "Backflow prevention device testing and reporting, per Louisiana requirements.",
        icon: :droplet,
        tabs: [
          { label: "Overview", path: :backflow_root_path },
          { label: "Testers", path: :backflow_testers_path }
        ].freeze
      )
    ].freeze

    BY_KEY = DEFINITIONS.index_by(&:key).freeze

    module_function

    def all
      DEFINITIONS
    end

    # Exact match on the string form, so "Backflow" is not "backflow".
    def find(key)
      BY_KEY[key.to_s]
    end

    def keys
      BY_KEY.keys
    end
  end
end
