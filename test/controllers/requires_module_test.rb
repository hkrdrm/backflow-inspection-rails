require "test_helper"

class RequiresModuleTest < ActiveSupport::TestCase
  # A typo in `requires_module` must fail at load time, not 404 every tenant.
  test "an unknown module key raises when declared" do
    assert_raises(ArgumentError) do
      Class.new(ApplicationController) do
        include RequiresModule
        requires_module :nope
      end
    end
  end
end
