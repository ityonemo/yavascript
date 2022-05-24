Yavascript.SpiderMonkeyEngine.init()

ExUnit.start()

ExUnit.stop(fn ->
  IO.puts("hi mom")
  Process.sleep(1000)
  Yavascript.SpiderMonkeyEngine.shutdown()
end)
