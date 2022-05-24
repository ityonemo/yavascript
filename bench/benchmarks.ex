defmodule Yavascript.Benchmarks do
  def build(benchmarks) do
    benchmarks
    |> Enum.map(
      fn module->
        quote do
          benchmark_module = Module.concat(unquote(module), Benchmark)
          defmodule benchmark_module do
            use Yavascript,
              engine: unquote(module),
              import: [my_function: 2],
              script: """
                const my_function = (a, b) => a + b;
              """
          end
        end
      end)
    |> Enum.each(&Code.eval_quoted/1)
  end
end
