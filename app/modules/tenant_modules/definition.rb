module TenantModules
  # One feature area a tenant can be given. Paths are route-helper names
  # (symbols), resolved in views, so the registry never depends on routes being
  # loaded.
  #
  #   key   - lowercase string; also the code namespace and route namespace
  #   icon  - shared/icon name for the module's sidebar link
  #   tabs  - [{ label: String, path: Symbol }], the module's own navigation,
  #           shown as tabs on every page in the module. The first is home.
  Definition = Data.define(:key, :name, :description, :icon, :tabs) do
    # Where the sidebar link and dashboard card go: the first tab.
    def home_path
      tabs.first[:path]
    end
  end
end
