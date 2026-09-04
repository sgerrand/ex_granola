defmodule GranolaTest do
  use ExUnit.Case

  test "new/1 returns a Client struct" do
    client = Granola.new(api_key: "grn_test")
    assert %Granola.Client{} = client
  end

  test "new/1 decodes keys as atoms by default" do
    assert %Granola.Client{keys: :atoms} = Granola.new(api_key: "grn_test")
  end

  test "new/1 accepts keys: :strings" do
    assert %Granola.Client{keys: :strings} = Granola.new(api_key: "grn_test", keys: :strings)
  end

  test "new/1 rejects an unknown :keys value" do
    assert_raise ArgumentError, ~r/expected :keys to be one of/, fn ->
      Granola.new(api_key: "grn_test", keys: :charlists)
    end
  end

  test "new/1 does not pass :keys through to Req" do
    client = Granola.new(api_key: "grn_test", keys: :strings)
    refute Map.has_key?(client.req.options, :keys)
  end
end
