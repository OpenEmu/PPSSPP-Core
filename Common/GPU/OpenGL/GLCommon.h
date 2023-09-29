#pragma once

#include "ppsspp_config.h"

#if PPSSPP_PLATFORM(IOS)
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#elif defined(USING_GLES2)
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#define GL_BGRA_EXT 0x80E1
#else // OpenGL
//We will not use glew in OpenEmu Core
//#include "GL/glew.h"
#if defined(__APPLE__)
#include <OpenGL/gl.h>
//#include <OpenGL/glext.h>
#include <OpenGL/gl3.h>
#include <OpenGL/gl3ext.h>
#else
#include <GL/gl.h>
#endif
#endif

#ifdef USING_GLES2
// Support OpenGL ES 3.0
// This uses the "DYNAMIC" approach from the gles3jni NDK sample.
#include "Common/GPU/OpenGL/gl3stub.h"
#endif

#ifdef USING_GLES2

#ifndef GL_MIN_EXT
#define GL_MIN_EXT 0x8007
#endif

#ifndef GL_MAX_EXT
#define GL_MAX_EXT 0x8008
#endif

#if defined(__ANDROID__)
#include <EGL/egl.h>
// Additional extensions not included in GLES2/gl2ext.h from the NDK

typedef uint64_t EGLuint64NV;
typedef EGLuint64NV(EGLAPIENTRYP PFNEGLGETSYSTEMTIMEFREQUENCYNVPROC) (void);
typedef EGLuint64NV(EGLAPIENTRYP PFNEGLGETSYSTEMTIMENVPROC) (void);
extern PFNEGLGETSYSTEMTIMEFREQUENCYNVPROC eglGetSystemTimeFrequencyNV;
extern PFNEGLGETSYSTEMTIMENVPROC eglGetSystemTimeNV;

typedef GLvoid* (GL_APIENTRYP PFNGLMAPBUFFERPROC) (GLenum target, GLenum access);
extern PFNGLMAPBUFFERPROC glMapBuffer;

typedef void (EGLAPIENTRYP PFNGLDRAWTEXTURENVPROC) (GLuint texture, GLuint sampler, GLfloat x0, GLfloat y0, GLfloat x1, GLfloat y1, GLfloat z, GLfloat s0, GLfloat t0, GLfloat s1, GLfloat t1);
extern PFNGLDRAWTEXTURENVPROC glDrawTextureNV;
#if !PPSSPP_ARCH(ARM64)
typedef void (EGLAPIENTRYP PFNGLBLITFRAMEBUFFERNVPROC) (
    GLint srcX0, GLint srcY0, GLint srcX1, GLint srcY1,
    GLint dstX0, GLint dstY0, GLint dstX1, GLint dstY1,
    GLbitfield mask, GLenum filter);
#endif
extern PFNGLBLITFRAMEBUFFERNVPROC glBlitFramebufferNV;

#if PPSSPP_PLATFORM(IOS)
extern PFNGLDISCARDFRAMEBUFFEREXTPROC glDiscardFramebufferEXT;
extern PFNGLGENVERTEXARRAYSOESPROC glGenVertexArraysOES;
extern PFNGLBINDVERTEXARRAYOESPROC glBindVertexArrayOES;
extern PFNGLDELETEVERTEXARRAYSOESPROC glDeleteVertexArraysOES;
extern PFNGLISVERTEXARRAYOESPROC glIsVertexArrayOES;

// Rename standard functions to the OES version.
#define glGenVertexArrays glGenVertexArraysOES
#define glBindVertexArray glBindVertexArrayOES
#define glDeleteVertexArrays glDeleteVertexArraysOES
#define glIsVertexArray glIsVertexArrayOES
#endif

#endif

#ifndef GL_READ_FRAMEBUFFER
#define GL_READ_FRAMEBUFFER GL_FRAMEBUFFER
#define GL_DRAW_FRAMEBUFFER GL_FRAMEBUFFER
#endif
#ifndef GL_DEPTH_COMPONENT24
#define GL_DEPTH_COMPONENT24 GL_DEPTH_COMPONENT24_OES
#endif

#ifndef GL_RGBA8
#define GL_RGBA8 GL_RGBA
#endif

#endif /* EGL_NV_system_time */

#ifndef GL_DEPTH24_STENCIL8_OES
#define GL_DEPTH24_STENCIL8_OES 0x88F0
#endif

#ifndef GL_COMPRESSED_RGB8_ETC2
#define GL_COMPRESSED_RGB8_ETC2 0x9274
#endif
#ifndef GL_COMPRESSED_RGBA_ASTC_4x4_KHR
#define GL_COMPRESSED_RGBA_ASTC_4x4_KHR 0x93B0
#endif
#ifndef GL_COMPRESSED_RGBA_BPTC_UNORM
#define GL_COMPRESSED_RGBA_BPTC_UNORM 0x8E8C
#endif
#ifndef GL_COMPRESSED_RGBA8_ETC2_EAC
#define GL_COMPRESSED_RGBA8_ETC2_EAC 0x9278
#endif
#ifndef GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2
#define GL_COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2 0x9276
#endif


// OpenEmu workaraounds for limitations in Apple's OpenGL
#define GL_COMPUTE_SHADER 0x91B9
#define GL_DEBUG_SOURCE_APPLICATION 0x824A

static void (*glCopyImageSubData)(GLuint srcName, GLenum srcTarget, GLint srcLevel, GLint srcX, GLint srcY, GLint srcZ, GLuint dstName, GLenum dstTarget, GLint dstLevel, GLint dstX, GLint dstY, GLint dstZ, GLsizei srcWidth, GLsizei srcHeight, GLsizei srcDepth) = 0;
static void (*glCopyImageSubDataNV)(GLuint srcName, GLenum srcTarget, GLint srcLevel, GLint srcX, GLint srcY, GLint srcZ, GLuint dstName, GLenum dstTarget, GLint dstLevel, GLint dstX, GLint dstY, GLint dstZ, GLsizei srcWidth, GLsizei srcHeight, GLsizei srcDepth) = 0;
static void  (*glBufferStorage) (GLenum target, GLsizeiptr size, const void *data, GLbitfield flags) = 0;
static void (*glGetTextureSubImage)(GLuint texture, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLenum type, GLsizei bufSize, void *pixels) = 0;
static void (*glPushDebugGroup)(GLenum source, GLuint id, GLsizei length, const char * message) = 0;
static void (*glPopDebugGroup)(void) = 0;
