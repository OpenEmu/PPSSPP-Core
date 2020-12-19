#pragma once

#ifdef IOS
#include <OpenGLES/ES3/gl.h>
#include <OpenGLES/ES3/glext.h>
#elif defined(USING_GLES2)
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
// At least Nokia platforms need the three below
#include <KHR/khrplatform.h>
typedef char GLchar;
#define GL_BGRA_EXT 0x80E1
#else // OpenGL
// OpenEmu will not use GLEW
//#include "GL/glew.h"
#if defined(__APPLE__)
#include <OpenGL/gl.h>
#include <OpenGL/gl3.h>
#include <OpenGL/gl3ext.h>
#else
#include <GL/gl.h>
#endif
#endif

#ifdef USING_GLES2
// Support OpenGL ES 3.0
// This uses the "DYNAMIC" approach from the gles3jni NDK sample.
#include "../gfx_es2/gl3stub.h"
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
#ifndef ARM64
typedef void (EGLAPIENTRYP PFNGLBLITFRAMEBUFFERNVPROC) (
GLint srcX0, GLint srcY0, GLint srcX1, GLint srcY1,
GLint dstX0, GLint dstY0, GLint dstX1, GLint dstY1,
GLbitfield mask, GLenum filter);
#endif
extern PFNGLBLITFRAMEBUFFERNVPROC glBlitFramebufferNV;

#ifdef IOS
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

// OpenEmu workaraounds for limitations in Apple's OpenGL
#define GL_COMPUTE_SHADER 0x91B9
#define GL_RENDERBUFFER_EXT GL_RENDERBUFFER
#define GL_FRAMEBUFFER_EXT GL_FRAMEBUFFER
#define GL_FRAMEBUFFER_COMPLETE_EXT GL_FRAMEBUFFER_COMPLETE
#define GL_FRAMEBUFFER_UNSUPPORTED_EXT GL_FRAMEBUFFER_UNSUPPORTED
#define GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_EXT GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT
#define GL_FRAMEBUFFER_BINDING_EXT GL_FRAMEBUFFER_BINDING
#define GL_DEPTH_STENCIL_EXT GL_DEPTH_STENCIL
#define GL_DEPTH_ATTACHMENT_EXT GL_DEPTH_ATTACHMENT
#define GL_STENCIL_ATTACHMENT_EXT GL_STENCIL_ATTACHMENT
#define GL_COLOR_ATTACHMENT0_EXT GL_COLOR_ATTACHMENT0
#define GL_BGRA_EXT GL_BGRA

#define glGenerateMipmapEXT glGenerateMipmap
#define glGenFramebuffersEXT glGenFramebuffers
#define glBindFramebufferEXT glBindFramebuffer
#define glCheckFramebufferStatusEXT glCheckFramebufferStatus
#define glFramebufferTexture2DEXT glFramebufferTexture2D
#define glDeleteFramebuffersEXT glDeleteFramebuffers
#define glFramebufferRenderbufferEXT glFramebufferRenderbuffer
#define glGenRenderbuffersEXT glGenRenderbuffers
#define glBindRenderbufferEXT glBindRenderbuffer
#define glRenderbufferStorageEXT glRenderbufferStorage
#define glDeleteRenderbuffersEXT glDeleteRenderbuffers

static void (*glInvalidateFramebuffer)(GLenum target, GLsizei numAttachments, const GLenum* attachments) = 0;
static void (*glCopyImageSubData)(GLuint srcName, GLenum srcTarget, GLint srcLevel, GLint srcX, GLint srcY, GLint srcZ, GLuint dstName, GLenum dstTarget, GLint dstLevel, GLint dstX, GLint dstY, GLint dstZ, GLsizei srcWidth, GLsizei srcHeight, GLsizei srcDepth) = 0;
static void (*glCopyImageSubDataNV)(GLuint srcName, GLenum srcTarget, GLint srcLevel, GLint srcX, GLint srcY, GLint srcZ, GLuint dstName, GLenum dstTarget, GLint dstLevel, GLint dstX, GLint dstY, GLint dstZ, GLsizei srcWidth, GLsizei srcHeight, GLsizei srcDepth) = 0;
static void  (*glBufferStorage) (GLenum target, GLsizeiptr size, const void *data, GLbitfield flags) = 0;
static void (*glGetTextureSubImage)(GLuint texture, GLint level, GLint xoffset, GLint yoffset, GLint zoffset, GLsizei width, GLsizei height, GLsizei depth, GLenum format, GLenum type, GLsizei bufSize, void *pixels) = 0;
