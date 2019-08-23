defmodule Brook.Event.Kafka.Serializer.JsonTest do
  use ExUnit.Case

  describe "serialize/1" do
    test "encodes data as json" do
      data = %{"id" => 1, "name" => "bob"}
      expected_data = Jason.encode!(data)

      assert {:ok, expected_data} == Brook.Event.Kafka.Serializer.serialize(data)
    end

    test "structs are encoded as json and the struct name is returned" do
      data = %TempStruct{name: "Bob", age: 21, location: "Columbus"}

      expected =
        %{
          "name" => "Bob",
          "age" => 21,
          "location" => "Columbus"
        }
        |> Jason.encode!()

      assert {:ok, TempStruct, expected} == Brook.Event.Kafka.Serializer.serialize(data)
    end

    test "returns an error when unable to encode data" do
      data = %{one: {1, 2}}

      {:error, reason} = Jason.encode(data)

      assert {:error, reason} == Brook.Event.Kafka.Serializer.serialize(data)
    end

    test "returns an error when unable to encode struct" do
      data = %TempStruct{name: "Bob", age: 21..22, location: "Columbus"}

      {:error, reason} = Jason.encode(data)

      assert {:error, reason} == Brook.Event.Kafka.Serializer.serialize(data)
    end
  end

  describe "deserialize/2" do
    test "decodes json into map" do
      data = %{"id" => 1, "name" => "Roger"}
      assert {:ok, data} == Brook.Event.Kafka.Deserializer.deserialize(:undefined, Jason.encode!(data))
    end

    test "decodes json into struct" do
      data = %{"name" => "Corey", "age" => 33, "location" => "Hawaii"} |> Jason.encode!()

      expected = %TempStruct{name: "Corey", age: 33, location: "Hawaii"}

      assert {:ok, expected} == Brook.Event.Kafka.Deserializer.deserialize(%TempStruct{}, data)
    end

    test "returns error when unable to decode input" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Event.Kafka.Deserializer.deserialize(:undefined, data)
    end

    test "returns error when unable to decode json for struct" do
      data = "[\"one\""

      {:error, reason} = Jason.decode(data)

      assert {:error, reason} == Brook.Event.Kafka.Deserializer.deserialize(%TempStruct{}, data)
    end
  end
end
