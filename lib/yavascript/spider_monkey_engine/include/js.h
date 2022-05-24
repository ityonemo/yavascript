#ifndef JS_H
#define JS_H

#ifdef __cplusplus
  #define JS_EXTERN extern "C"
#else
  #define JS_EXTERN
#endif

#include <stdint.h>

typedef struct JSContext Context;

typedef struct {
  void* global;
  void* realm;
} GlobalInfo;

typedef void (*result_fn_t)(const char *, void *);

JS_EXTERN void init();
JS_EXTERN void shutdown();

JS_EXTERN void executeCode(Context *, const char*, const void *, void *);

JS_EXTERN Context* newContext(uint32_t max_bytes);

// type erasure is necessary here to get it past the C ABI?
// note that the two void* terms here should be the same.
JS_EXTERN GlobalInfo initializeContext(Context *);
JS_EXTERN void cleanupGlobals(Context *, GlobalInfo);

JS_EXTERN void destroyContext(Context *);

#endif