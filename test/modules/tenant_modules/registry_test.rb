require "test_helper"

class TenantModules::RegistryTest < ActiveSupport::TestCase
  Registry = TenantModules::Registry

  test "declares the backflow module" do
    backflow = Registry.find("backflow")

    assert_equal "Backflow Inspections", backflow.name
    assert_equal :backflow_root_path, backflow.home_path
  end

  test "backflow declares its pages, and home is the first one" do
    backflow = Registry.find("backflow")

    assert_equal [ "Overview", "Testers" ], backflow.pages.map { |page| page[:label] }
    assert_equal [ :backflow_root_path, :backflow_testers_path ], backflow.pages.map { |page| page[:path] }
    assert_equal backflow.pages.first[:path], backflow.home_path
  end

  test "finds by symbol or string" do
    assert_equal Registry.find("backflow"), Registry.find(:backflow)
  end

  test "unknown and differently cased keys are not found" do
    assert_nil Registry.find("nope")
    assert_nil Registry.find("Backflow")
  end

  test "keys are unique lowercase strings" do
    keys = Registry.keys

    assert_equal keys.uniq, keys
    keys.each { |key| assert_match(/\A[a-z][a-z0-9_]*\z/, key) }
  end

  test "keys follow all" do
    assert_equal Registry.all.map(&:key), Registry.keys
  end

  test "declares the example template module" do
    example = Registry.find("example")

    assert_equal "Example Module", example.name
    assert_equal [ "Overview", "Items" ], example.pages.map { |page| page[:label] }
  end

  # Shipping a module in code must not switch it on for anyone.
  test "the example module ships disabled platform-wide" do
    assert_equal "disabled", PlatformModule.status_for(:example)
  end
end
