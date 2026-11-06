module Example
  # A list and an add form: the smallest useful CRUD to copy.
  class ItemsController < BaseController
    def index
      @items = Item.for_tenant(current_tenant).order(:name).all
    end

    def new
      @item = Item.new
    end

    def create
      # tenant_id comes from the session, never from params, so a crafted form
      # cannot write into another tenant.
      @item = Item.new(item_params)
      @item.tenant_id = current_tenant.id

      if @item.save(raise_on_failure: false)
        redirect_to example_items_path, notice: "#{@item.name} added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def item_params
      params.require(:item).permit(:name, :notes).to_h
    end
  end
end
