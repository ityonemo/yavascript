require Yavascript.Benchmarks

engines =
  [Yavascript.BunEngine,
  Yavascript.DenoEngine,
  Yavascript.NodeEngine,
  Yavascript.SpiderMonkeyEngine,
  Yavascript.MozjsEngine]

Yavascript.Benchmarks.build(engines)

defmodule Mix.Tasks.Benchmark do
  def run(_) do
    Yavascript.SpiderMonkeyEngine.init();

    engines = unquote(engines)

    contexts = Map.new(engines, &{&1, Module.concat(&1, Benchmark).setup()})

    engines
    |> Map.new(fn engine ->
      benchmark = Module.concat(engine, Benchmark)
      name = "#{inspect engine}"
      {name, fn ->
        Process.put(:js_context, contexts[engine])
        benchmark.my_function("foo", "bar")
      end}
    end)
    |> Benchee.run
  end
end
