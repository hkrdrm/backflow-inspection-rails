module Example
  # The module's first page, which the sidebar link and overview card open.
  class HomeController < BaseController
    def show
      @item_count = Item.for_tenant(current_tenant).count
    end
  end
end
