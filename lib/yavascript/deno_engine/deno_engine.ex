defmodule Yavascript.DenoEngine do
  def create_context, do: make_ref()

  def run_script(context, code, needs_result) do
    if needs_result do
      full_code = """
      #{context}

      #{code}
      """

      {result, 0} = System.cmd("deno", ["eval", full_code])

      Jason.decode!(result)
    else
      # this is the base function
      Process.put(:js_context, code)
      code
    end
  end

  @spec _build_function({atom, non_neg_integer}) :: Macro.t()
  def _build_function({fun, arity}) do
    args =
      case arity do
        0 -> []
        n -> for i <- 1..n, do: {:"arg#{i}", [], Elixir}
      end

    quote do
      def unquote(fun)(unquote_splicing(args)) do
        context = Process.get(:js_context) || raise "no context!"

        arguments = Jason.encode!(unquote(args))
        code = "console.log(JSON.stringify(#{unquote(fun)}(...JSON.parse('#{arguments}'))))"

        Yavascript.DenoEngine.run_script(context, code, true)
      end
    end
  end
end
