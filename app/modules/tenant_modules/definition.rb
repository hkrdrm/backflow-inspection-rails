module TenantModules
  # One feature area a tenant can be given. Paths are route-helper names
  # (symbols), resolved in views, so the registry never depends on routes being
  # loaded.
  #
  #   key         - lowercase string; also the code namespace and route namespace
  #   home_path   - the module's landing page, linked from the core dashboard
  #   nav_items   - [{ label: String, icon: Symbol, path: Symbol }] for the sidebar
  Definition = Data.define(:key, :name, :description, :home_path, :nav_items)
end
