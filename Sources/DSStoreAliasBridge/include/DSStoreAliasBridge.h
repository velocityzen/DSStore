#ifndef DSSTORE_ALIAS_BRIDGE_H
#define DSSTORE_ALIAS_BRIDGE_H

#include <CoreFoundation/CoreFoundation.h>

CF_ASSUME_NONNULL_BEGIN

CFDataRef _Nullable DSStoreCreateAliasData(const char *targetPath);

CF_ASSUME_NONNULL_END

#endif
