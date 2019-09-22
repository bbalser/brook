defmodule Brook.GetTest do
  use ExUnit.Case

  @instance :brook_test

  test "get raises an exception if the server table is not available" do
    assert_raise Brook.Uninitialized, fn ->
      Brook.get(@instance, :all, 1)
    end
  end

  test "get raises an exception if the config is not in the table" do
    :ets.new(:brook_config_table, [:set, :protected, :named_table])

    assert_raise Brook.Uninitialized, fn ->
      Brook.get(@instance, :all, 1)
    end
  end
end
