defmodule Yavascript.Engine do
  @type context :: term

  @callback init() :: :ok
  @callback create_context() :: context
  @callback run_script(context, command :: String.t(), needs_result :: boolean) ::
              Yavascript.json() | :ok
  @callback _build_function({atom, non_neg_integer}) :: Macro.t()
end
