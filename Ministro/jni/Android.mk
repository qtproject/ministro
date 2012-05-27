LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE    := ministro
LOCAL_CFLAGS    := -Werror
LOCAL_SRC_FILES := chmode.c extract.cpp
LOCAL_LDLIBS    := -lm -llog

include $(BUILD_SHARED_LIBRARY)
