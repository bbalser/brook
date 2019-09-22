defmodule Brook.Event.Kafka.Serializer.JsonTest do
  use ExUnit.Case

  describe "serialize/1" do
    test "encodes data as json" do
      event =
        Brook.Event.new(
          type: "update",
          author: "balser",
          data: %{"id" => 1, "name" => "bob"}
        )

      {:ok, expected} =
        %{
          "__brook_struct__" => "Elixir.Brook.Event",
          "type" => event.type,
          "author" => event.author,
          "create_ts" => event.create_ts,
          "data" => Jason.encode!(%{"id" => 1, "name" => "bob"}),
          "forwarded" => event.forwarded
        }
        |> Jason.encode()

      {:ok, actual} = Brook.Serializer.serialize(event) |> decode() |> encode()
      assert expected == actual
    end

    test "structs are encoded as json and the struct name is returned" do
      event =
        Brook.Event.new(
          type: "create",
          author: "joe",
          data: %TempStruct{name: "Bob", age: 21, location: "Columbus"}
        )

      expected =
        %{"__brook_struct__" => "Elixir.TempStruct", "name" => "Bob", "age" => 21, "location" => "Columbus"}
        |> Jason.encode()

      {:ok, actual} = Brook.Serializer.serialize(event) |> decode()
      assert expected == {:ok, actual["data"]} |> decode() |> encode()
    end

    test "returns an error when unable to encode data" do
      event =
        Brook.Event.new(
          type: "delete",
          author: "joe",
          data: %{one: {1, 2}}
        )

      {:error, reason} = Jason.encode(event)

      assert {:error, reason} == Brook.Serializer.serialize(event)
    end

    test "returns an error when unable to encode struct" do
      event =
        Brook.Event.new(
          type: "update",
          author: "people",
          data: %TempStruct{name: "Bob", age: 21..22, location: "Columbus"}
        )

      {:error, reason} = Jason.encode(event)

      assert {:error, reason} == Brook.Serializer.serialize(event)
    end
  end

  describe "deserialize/2" do
    test "decodes json into map" do
      json =
        %{
          "__brook_struct__" => "Elixir.Brook.Event",
          "type" => "update",
          "author" => "george",
          "create_ts" => 0,
          "data" => %{"id" => 1, "name" => "Roger"} |> Jason.encode!()
        }
        |> Jason.encode!()

      expected =
        Brook.Event.new(
          type: "update",
          author: "george",
          create_ts: 0,
          data: %{"id" => 1, "name" => "Roger"}
        )

      assert {:ok, expected} == Brook.Deserializer.deserialize(json)
    end

    test "decodes json into struct" do
      json =
        %{
          "type" => "create",
          "author" => "Howard",
          "create_ts" => 0,
          "__brook_struct__" => "Elixir.Brook.Event",
          "data" =>
            %{"__brook_struct__" => "Elixir.TempStruct", "name" => "Corey", "age" => 33, "location" => "Hawaii"}
            |> Jason.encode!()
        }
        |> Jason.encode!()

      expected =
        Brook.Event.new(
          type: "create",
          author: "Howard",
          create_ts: 0,
          data: %TempStruct{name: "Corey", age: 33, location: "Hawaii"}
        )

      assert {:ok, expected} == Brook.Deserializer.deserialize(struct(Brook.Event), json)
    end

    test "returns error when unable to decode input" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Deserializer.deserialize(:undefined, data)
    end

    test "returns error when unable to decode json for struct" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Deserializer.deserialize(%TempStruct{}, data)
    end
  end

  defp encode({:ok, value}), do: {:ok, Jason.encode!(value)}
  defp decode({:ok, value}), do: {:ok, Jason.decode!(value)}
end
