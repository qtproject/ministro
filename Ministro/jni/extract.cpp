/*
    Copyright (c) 2011, BogDan Vatra <bog_dan_ro@yahoo.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#include <jni.h>
#include <android/log.h>
#include <extract.h>
#include <alloca.h>

#define LOG_TAG    "extractSyleInfo"
#define LOGI(...)  __android_log_print(ANDROID_LOG_INFO,LOG_TAG,__VA_ARGS__)
#define LOGE(...)  __android_log_print(ANDROID_LOG_ERROR,LOG_TAG,__VA_ARGS__)
#define LOGF(...)  __android_log_print(ANDROID_LOG_FATAL,LOG_TAG,__VA_ARGS__)

const char * const NinePatchDrawableClassName = "android/graphics/drawable/NinePatchDrawable";
const char * const NinePatchFieldIDName = "mNinePatch";
static jfieldID m_ninePatchFieldID=0;

const char * const NinePatchClassName = "android/graphics/NinePatch";
const char * const ChunkFieldIDName = "mChunk";
static jfieldID m_chunkFieldID=0;

const char * const ClipStateClassName = "android/graphics/drawable/ClipDrawable$ClipState";
const char * const ClipStateDrawableFieldIDName = "mDrawable";
static jfieldID m_clipStateDrawableFieldID=0;

bool setup(JNIEnv * env, jobject /*obj*/)
{
    jclass ninePatchClass = env->FindClass(NinePatchClassName);
    if (!ninePatchClass)
    {
        LOGF("Unable to find class '%s'", NinePatchClassName);
        return JNI_FALSE;
    }

    m_chunkFieldID = env->GetFieldID(ninePatchClass, ChunkFieldIDName, "[B");
    if(!m_chunkFieldID)
    {
        LOGF("Unable to find field '%s'", ChunkFieldIDName);
        return JNI_FALSE;
    }

    jclass ninePatchDrawableClass = env->FindClass(NinePatchDrawableClassName);
    if (!ninePatchDrawableClass)
    {
        LOGF("Unable to find class '%s'", NinePatchDrawableClassName);
        return JNI_FALSE;
    }

    m_ninePatchFieldID = env->GetFieldID(ninePatchDrawableClass, NinePatchFieldIDName, "Landroid/graphics/NinePatch;");
    if(!m_ninePatchFieldID)
    {
        LOGF("Unable to find field '%s'", NinePatchFieldIDName);
        return JNI_FALSE;
    }

    jclass clipStateDrawableClass = env->FindClass(ClipStateClassName);
    if (!clipStateDrawableClass)
    {
        LOGF("Unable to find class '%s'", ClipStateClassName);
        return JNI_FALSE;
    }

    m_clipStateDrawableFieldID = env->GetFieldID(clipStateDrawableClass, ClipStateDrawableFieldIDName, "Landroid/graphics/drawable/Drawable;");
    if(!m_ninePatchFieldID)
    {
        LOGF("Unable to find field '%s'", NinePatchFieldIDName);
        return JNI_FALSE;
    }

    return JNI_TRUE;
}

static void printChunkInformation(Res_png_9patch* chunk)
{
    LOGI("printChunkInformation x:%d , y:%d",chunk->numXDivs, chunk->numYDivs);
    for (int x = 0; x < chunk->numXDivs; x ++)
        LOGI("X CHUNK %d %d", x, chunk->xDivs[x]);
    for (int y = 0; y < chunk->numYDivs; y ++)
        LOGI("Y CHUNK %d %d", y, chunk->yDivs[y]);
    LOGI("----");
}

extern "C" JNIEXPORT jintArray JNICALL Java_org_kde_necessitas_ministro_ExtractStyle_extractChunkInfo(JNIEnv * env, jobject  obj, jbyteArray chunkObj)
{
        size_t chunkSize = env->GetArrayLength(chunkObj);
        void* storage = alloca(chunkSize);
        env->GetByteArrayRegion(chunkObj, 0, chunkSize,
                                reinterpret_cast<jbyte*>(storage));

        if (!env->ExceptionCheck())
        {
            // need to deserialize the chunk
            Res_png_9patch* chunk = static_cast<Res_png_9patch*>(storage);
            Res_png_9patch::deserialize(chunk);
            printChunkInformation(chunk);
            jintArray result;
            size_t size = 3+chunk->numXDivs+chunk->numYDivs+chunk->numColors;
            result = env->NewIntArray(size);
            if (!result)
                return 0;

            jint *data = (jint*)malloc(sizeof(jint)*size);
            size_t pos = 0;
            data[pos++]=chunk->numXDivs;
            data[pos++]=chunk->numYDivs;
            data[pos++]=chunk->numColors;
            for (int x = 0; x <chunk->numXDivs; x ++)
                data[pos++]=chunk->xDivs[x];
            for (int y = 0; y <chunk->numYDivs; y ++)
                data[pos++]=chunk->yDivs[y];
            for (int c = 0; c <chunk->numColors; c ++)
                data[pos++]=chunk->colors[c];
            env->SetIntArrayRegion(result, 0, size, data);
            free(data);
            return result;
        }
        return 0;
}

extern "C" JNIEXPORT jintArray JNICALL Java_org_kde_necessitas_ministro_ExtractStyle_extract9PatchInfo(JNIEnv * env, jobject obj, jobject ninePatchObject)
{
    if (!m_ninePatchFieldID || !m_chunkFieldID)
        if (!setup(env, obj))
            return 0;
    return Java_org_kde_necessitas_ministro_ExtractStyle_extractChunkInfo(env, obj
                                                                                ,reinterpret_cast<jbyteArray>(env->GetObjectField(
                                                                                        env->GetObjectField(ninePatchObject, m_ninePatchFieldID)
                                                                                        , m_chunkFieldID)) );
}

extern "C" JNIEXPORT jobject JNICALL Java_org_kde_necessitas_ministro_ExtractStyle_getClipStateDrawableObject(JNIEnv * env, jobject obj, jobject clipStateObject)
{
    if (!m_ninePatchFieldID || !m_chunkFieldID || !m_clipStateDrawableFieldID)
        if (!setup(env, obj))
            return 0;
    return env->GetObjectField(clipStateObject, m_clipStateDrawableFieldID);
}

// The following part was shamelessly stolen from ResourceTypes.cpp Android's sources
static void deserializeInternal(const void* inData, Res_png_9patch* outData) {
    char* patch = (char*) inData;
    if (inData != outData) {
        memmove(&outData->wasDeserialized, patch, 4);     // copy  wasDeserialized, numXDivs, numYDivs, numColors
        memmove(&outData->paddingLeft, patch + 12, 4);     // copy  wasDeserialized, numXDivs, numYDivs, numColors
    }
    outData->wasDeserialized = true;
    char* data = (char*)outData;
    data +=  sizeof(Res_png_9patch);
    outData->xDivs = (int32_t*) data;
    data +=  outData->numXDivs * sizeof(int32_t);
    outData->yDivs = (int32_t*) data;
    data +=  outData->numYDivs * sizeof(int32_t);
    outData->colors = (uint32_t*) data;
}

Res_png_9patch* Res_png_9patch::deserialize(const void* inData)
{
    if (sizeof(void*) != sizeof(int32_t)) {
        LOGE("Cannot deserialize on non 32-bit system\n");
        return NULL;
    }
    deserializeInternal(inData, (Res_png_9patch*) inData);
    return (Res_png_9patch*) inData;
}
