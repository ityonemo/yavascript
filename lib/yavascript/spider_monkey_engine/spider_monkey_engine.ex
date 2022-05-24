defmodule Yavascript.SpiderMonkeyEngine do
  @behaviour Yavascript.Engine

  use Zig,
    link_libc: true,
    link_libcpp: true,
    include: ["/usr/include/mozjs-91"],
    system_libs: ["mozjs-91"],
    sources: [{"js.cpp", ["-std=c++17"]}]

  ~Z"""
  const js = @cImport({
    @cInclude("js.h");
  });

  /// nif: init/0
  fn init() void {
    js.init();
  }

  /// nif: shutdown/0
  fn shutdown() void {
    js.shutdown();
  }

  /// resource: threadinfo_ptr_t definition
  const threadinfo_ptr_t = *ThreadInfo;
  const ThreadInfo = struct {
    name: []u8,
    mutex: *e.ErlNifMutex,
    tid: e.ErlNifTid,
    called: bool,
    pid: beam.pid,
    command: []u8,
    needs_return: bool,
    active: bool,
  };

  /// resource: threadinfo_ptr_t cleanup
  fn struct_res_ptr_cleanup(_: beam.env, thread_info: *threadinfo_ptr_t) void {
    {
      e.enif_mutex_lock(thread_info.*.mutex);
      defer e.enif_mutex_unlock(thread_info.*.mutex);
      thread_info.*.active = false;
    }

    var result:?*anyopaque = undefined;

    _ = e.enif_thread_join(thread_info.*.tid, &result);
  }

  var default_thread_opts = e.ErlNifThreadOpts{ .suggested_stack_size = 0};
  const thread_name = "js-executor";

  /// nif: create_thread/0 dirty_cpu
  fn create_thread(env: beam.env) !beam.term {
    // we will sort unreachables later.
    var thread_name_slice = beam.allocator.alloc(u8, thread_name.len) catch unreachable;
    std.mem.copy(u8, thread_name_slice, thread_name);

    var thread_info = beam.allocator.create(ThreadInfo) catch unreachable;
    // NOTE: failures are not caught here, need to do this!
    thread_info.mutex = e.enif_mutex_create(thread_name_slice.ptr).?;
    thread_info.pid = beam.self(env) catch unreachable;
    thread_info.called = false;
    thread_info.active = true;

    var tcreate = e.enif_thread_create(
      thread_name_slice.ptr,
      &thread_info.tid,
      js_executor,
      thread_info,
      &default_thread_opts);

    if (tcreate == 0) {
      var abc = __resource__.create(threadinfo_ptr_t, env, thread_info);
      return abc;
    } else {
      // TODO: actually raise here.
      return beam.make_atom(env, "error");
    }
  }

  const ResponsePayload = struct{
    env: beam.env,
    binary_term: beam.term,
  };

  fn js_executor(thread_info_opaque: ?*anyopaque) callconv(.C) ?*anyopaque {
    var context = js.newContext(0).?;
    defer js.destroyContext(context);

    var global: js.GlobalInfo = js.initializeContext(context);
    defer js.cleanupGlobals(context, global);

    var env = e.enif_alloc_env();
    defer e.enif_free_env(env);

    var thread_info =
      @ptrCast(
        threadinfo_ptr_t,
        @alignCast(
          @alignOf(threadinfo_ptr_t),
          thread_info_opaque)
        );

    var mutex = thread_info.mutex;

    _ = beam.send_advanced(null, thread_info.pid, env, beam.make_atom(env, "unlock"));

    while (true) loop: {
      if (e.enif_mutex_trylock(mutex) == 0) {
        defer e.enif_mutex_unlock(mutex);

        if (!thread_info.active) break :loop;

        // check to make sure this_ref is different from the last ref.
        if (thread_info.called) {
          defer beam.allocator.free(thread_info.command);

          if (thread_info.needs_return) {
            var response: ResponsePayload = .{
              .env = env,
              .binary_term = undefined,
            };

            js.executeCode(context, thread_info.command.ptr, responseFn, &response);

            var tuple_terms = [_]beam.term{beam.make_atom(env, "js_result"), response.binary_term};

            _ = beam.send_advanced(null, thread_info.pid, env, beam.make_tuple(env, tuple_terms[0..]));
          } else {
            js.executeCode(context, thread_info.command.ptr, null, null);
            _ = beam.send_advanced(null, thread_info.pid, env, beam.make_atom(env, "js_ok"));
          }
          thread_info.called = false;
        }
      }
      // 100 us sleep time till next poll
      std.time.sleep(100_000);
    }

    return null;
  }

  fn responseFn(resp_text: [*c] const u8, response_opaque: ?*anyopaque) void {
    var response = @ptrCast(*ResponsePayload, @alignCast(@alignOf(*ResponsePayload), response_opaque.?));
    var response_slice = std.mem.sliceTo(resp_text, 0);

    response.binary_term = beam.make_slice(response.env, response_slice);
  }

  /// nif: execute/3 dirty_io
  fn execute(env: beam.env, thread_info_term: beam.term, command: []u8, needs_return: bool) beam.term {
    var thread_info = __resource__.fetch(threadinfo_ptr_t, env, thread_info_term)
      catch unreachable;
    var new_ref = e.enif_make_ref(env);

    {
      e.enif_mutex_lock(thread_info.mutex);
      defer e.enif_mutex_unlock(thread_info.mutex);

      // copy and null-terminate the command
      var command_copy = beam.allocator.alloc(u8, command.len + 1) catch unreachable;
      std.mem.copy(u8, command_copy, command);
      command_copy[command.len] = 0;

      // note that ownership of the command is going to pass to the thread.
      thread_info.called = true;
      thread_info.command = command_copy;
      thread_info.needs_return = needs_return;
      thread_info.pid = beam.self(env) catch unreachable;
    }

    return new_ref;
  }
  """

  def create_context do
    result = create_thread()
    receive do :unlock -> result end
  end

  def run_script(context, code, needs_return) do
    Yavascript.SpiderMonkeyEngine.execute(context, code, needs_return)
    receive do
      {:js_result, result} when needs_return -> Jason.decode!(result)
      :js_ok when not needs_return -> :ok
    end
  end

  @spec build_function({atom, non_neg_integer}) :: Macro.t
  def build_function({fun, arity}) do
    args = case arity do
      0 -> []
      n -> for i <- 1..n, do: {:"arg#{i}", [], Elixir}
    end

    quote do
      def unquote(fun)(unquote_splicing(args)) do
        context = Process.get(:context) || raise "no context!"

        arguments = Jason.encode!(unquote(args))
        code = "JSON.stringify(#{unquote(fun)}(...JSON.parse('#{arguments}')))"

        Yavascript.SpiderMonkeyEngine.run_script(context, code, true)
      end
    end
  end
end
