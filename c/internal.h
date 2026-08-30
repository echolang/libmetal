#ifndef ECHO_MTL_INTERNAL_H
#define ECHO_MTL_INTERNAL_H

#import "mtl.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

#include <TargetConditionals.h>
#include <string.h>

void mtl_copy_nsstring(NSString *s, char *buf, size_t cap);
void mtl_copy_error(NSError *err, char *buf, size_t cap);
id mtl_id(void *p);
void *mtl_retain_id(id obj);

#endif
