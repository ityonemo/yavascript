defmodule Yavascript do
  defmacro __using__(opts!) do
    {opts!, _} = Code.eval_quoted(opts!, [], __CALLER__)
    engine = Keyword.fetch!(opts!, :engine)

    functions = opts!
    |> Keyword.fetch!(:import)
    |> Enum.map(&engine.build_function(&1))

    script = Keyword.fetch!(opts!, :script)

    setup = Keyword.get(opts!, :setup, :setup)

    quote do
      def unquote(setup)() do
        context = unquote(engine).create_context()
        unquote(engine).run_script(context, unquote(script), false)

        Process.put(:context, context)

        context
      end

      unquote_splicing(functions)
    end
  end
end
