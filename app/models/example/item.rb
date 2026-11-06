module Example
  # A row of the example module's data. Module models live in the module's
  # namespace and table (example_items), and core models never point at them:
  # Tenant has no `example_items` association. Reach the data with
  # `Example::Item.for_tenant(current_tenant)` instead.
  class Item < Sequel::Model(:example_items)
    plugin :validation_helpers
    # The naming/to_key interface form_with needs.
    plugin :active_model
    plugin :timestamps, update_on_create: true

    many_to_one :tenant

    dataset_module do
      # The only way controllers should load items: scoped to one tenant.
      def for_tenant(tenant)
        where(tenant_id: tenant.id)
      end
    end

    def validate
      super
      validates_presence [ :tenant_id, :name ]
    end
  end
end
