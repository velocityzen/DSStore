#include "DSStoreAliasBridge.h"

#include <TargetConditionals.h>

#if TARGET_OS_OSX
#include <CoreServices/CoreServices.h>
#endif

CFDataRef DSStoreCreateAliasData(const char *targetPath) {
#if TARGET_OS_OSX
  AliasHandle alias = NULL;
  OSStatus status = FSNewAliasFromPath(NULL, targetPath, 0, &alias, NULL);
  if (status != noErr || alias == NULL) {
    return NULL;
  }

  Size size = GetAliasSizeFromPtr(*alias);
  CFDataRef data = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)(*alias), size);
  DisposeHandle((Handle)alias);
  return data;
#else
  (void)targetPath;
  return NULL;
#endif
}
