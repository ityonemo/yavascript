Yavascript.SpiderMonkeyEngine.init()

ExUnit.start()

ExUnit.stop(fn ->
  Process.sleep(100)
  Yavascript.SpiderMonkeyEngine.shutdown()
end)
