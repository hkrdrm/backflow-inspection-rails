module TenantModules
  # One feature area a tenant can be given. Paths are route-helper names
  # (symbols), resolved in views, so the registry never depends on routes being
  # loaded.
  #
  #   key   - lowercase string; also the code namespace and route namespace
  #   icon  - shared/icon name for the module's sidebar link
  #   pages - [{ label: String, path: Symbol }], the module's own navigation,
  #           listed under the module in the sidebar while you're inside it.
  #           The first is the module's home.
  Definition = Data.define(:key, :name, :description, :icon, :pages) do
    # Where the sidebar link and dashboard card go: the first page.
    def home_path
      pages.first[:path]
    end
  end
end
