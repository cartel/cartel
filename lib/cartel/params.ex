defmodule Cartel.Params do
  @callback to_params(struct) :: map
  @callback from_params(map) :: struct

  def from_struct(implementation, struct) do
    implementation.to_params(struct)
  end

  def to_struct(implementation, params) do
    implementation.from_params(params)
  end
end
