defmodule Brook.Event.Kafka.Serializer.JsonTest do
  use ExUnit.Case

  describe "serialize/1" do
    test "encodes data as json" do
      event = %Brook.Event{
        type: "update",
        author: "balser",
        data: %{"id" => 1, "name" => "bob"}
      }

      expected = %{
        "type" => event.type,
        "author" => event.author,
        "create_ts" => event.create_ts,
        "data" => Jason.encode!(%{"id" => 1, "name" => "bob"})
      } |> Jason.encode!() |> Jason.decode!()

      assert {:ok, expected} == Brook.Event.Serializer.serialize(event) |> decode()
    end

    test "structs are encoded as json and the struct name is returned" do
      event = %Brook.Event{
        type: "create",
        author: "joe",
        data: %TempStruct{name: "Bob", age: 21, location: "Columbus"}
      }

      expected = %{
        "type" => "create",
        "author" => "joe",
        "create_ts" => event.create_ts,
        "__struct__" => "Elixir.TempStruct",
        "data" => Jason.encode!(%{"name" => "Bob", "age" => 21, "location" => "Columbus"})
      } |> Jason.encode!() |> Jason.decode!()

      assert {:ok, expected} == Brook.Event.Serializer.serialize(event) |> decode()
    end

    test "returns an error when unable to encode data" do
      event = %Brook.Event{
        type: "delete",
        author: "joe",
        data: %{one: {1, 2}}
      }

      {:error, reason} = Jason.encode(event)

      assert {:error, reason} == Brook.Event.Serializer.serialize(event)
    end

    test "returns an error when unable to encode struct" do
      event = %Brook.Event{
        type: "update",
        author: "people",
        data: %TempStruct{name: "Bob", age: 21..22, location: "Columbus"}
      }

      {:error, reason} = Jason.encode(event)

      assert {:error, reason} == Brook.Event.Serializer.serialize(event)
    end
  end

  describe "deserialize/2" do
    test "decodes json into map" do
      json = %{
        "type" => "update",
        "author" => "george",
        "data" => %{"id" => 1, "name" => "Roger"} |> Jason.encode!()
      } |> Jason.encode!()

      expected = %Brook.Event{
        type: "update",
        author: "george",
        data: %{"id" => 1, "name" => "Roger"}
      }

      assert {:ok, expected} == Brook.Event.Deserializer.deserialize(struct(Brook.Event), json)
    end

    test "decodes json into struct" do
      json = %{
        "type" => "create",
        "author" => "Howard",
        "__struct__" => "Elixir.TempStruct",
        "data" => %{"name" => "Corey", "age" => 33, "location" => "Hawaii"} |> Jason.encode!()
      } |> Jason.encode!()

      expected = %Brook.Event{
        type: "create",
        author: "Howard",
        data: %TempStruct{name: "Corey", age: 33, location: "Hawaii"}
      }

      assert {:ok, expected} == Brook.Event.Deserializer.deserialize(struct(Brook.Event), json)
    end

    test "returns error when unable to decode input" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Event.Deserializer.deserialize(:undefined, data)
    end

    test "returns error when unable to decode json for struct" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Event.Deserializer.deserialize(%TempStruct{}, data)
    end
  end

  defp decode({:ok, value}), do: {:ok, Jason.decode!(value)}

end
