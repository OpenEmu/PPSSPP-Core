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
//#include <GL/glew.h>
#if defined(__APPLE__)
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
#define GL_LUMINANCE 0x1909
#define GL_LOGIC_OP 0x0BF1
#define GL_STACK_OVERFLOW 0x0503
#define GL_STACK_UNDERFLOW 0x0504

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

