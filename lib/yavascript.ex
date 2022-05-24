defmodule Yavascript do
  @type json :: String.t() | number | boolean | nil | [json] | %{optional(String.t()) => json}
  defmacro __using__(opts!) do
    {opts!, _} = Code.eval_quoted(opts!, [], __CALLER__)
    engine = Keyword.fetch!(opts!, :engine)

    functions =
      opts!
      |> Keyword.fetch!(:import)
      |> Enum.map(&engine._build_function(&1))

    script = Keyword.fetch!(opts!, :script)

    setup = Keyword.get(opts!, :setup, :setup)

    quote do
      def unquote(setup)() do
        context = unquote(engine).create_context()

        Process.put(:js_context, context)

        unquote(engine).run_script(context, unquote(script), false)
      end

      unquote_splicing(functions)
    end
  end
end
