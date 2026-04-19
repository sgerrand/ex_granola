defmodule GranolaTest do
  use ExUnit.Case

  test "new/1 returns a Client struct" do
    client = Granola.new(api_key: "grn_test")
    assert %Granola.Client{} = client
  end
end
