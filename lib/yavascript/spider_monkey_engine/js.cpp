#include "js.h"
#include <jsapi.h>
#include <js/Initialization.h>
#include <js/Context.h>
#include <js/CompilationAndEvaluation.h>
#include <js/SourceText.h>

#define RootedObject JS::RootedObject

extern "C" void init() {
    JS_Init();
}

extern "C" void shutdown() {
    JS_ShutDown();
}

extern "C" Context* newContext(uint32_t max_bytes) {
    if (max_bytes) {
        return JS_NewContext(max_bytes);
    } else {
        return JS_NewContext(JS::DefaultHeapMaxBytes);
    }
}

extern "C" void destroyContext(Context* context) {
  JS_DestroyContext(context);
}

JSObject* createGlobal(Context* cx) {
  JS::RealmOptions options;

  static JSClass BoilerplateGlobalClass = {
      "BoilerplateGlobal", JSCLASS_GLOBAL_FLAGS, &JS::DefaultGlobalClassOps};

  return JS_NewGlobalObject(cx, &BoilerplateGlobalClass, nullptr,
                            JS::FireOnNewGlobalHook, options);
}

extern "C" GlobalInfo initializeContext(Context *context) {
  // note: check for failure
  JS::InitSelfHostedCode(context);

  RootedObject *global = new RootedObject(context, createGlobal(context));
  JSAutoRealm *realm = new JSAutoRealm(context, *global);

  // set up the packed struct to return.
  GlobalInfo info;
  info.global = (void *) global;
  info.realm = (void *) realm;
  return info;
}

extern "C" void cleanupGlobals(Context *context, GlobalInfo info) {
    delete (RootedObject *) info.global;
    delete (JSAutoRealm *) info.realm;
}

extern "C" void executeCode(Context *context, const char* code, const void * r_fn_ptr, void * r_fn_arg) {
    JS::CompileOptions options(context);
    options.setFileAndLine("noname", 1);

    JS::SourceText<mozilla::Utf8Unit> source;

    // NOTE: check failure.
    source.init(context, code, strlen(code), JS::SourceOwnership::Borrowed);

    JS::RootedValue rval(context);

    // NOTE: check failure
    JS::Evaluate(context, options, source, &rval);

    if (r_fn_ptr != nullptr) {
        result_fn_t r_fn = (result_fn_t) r_fn_ptr;
        r_fn(JS_EncodeStringToASCII(context, rval.toString()).get(), r_fn_arg);
    }
}