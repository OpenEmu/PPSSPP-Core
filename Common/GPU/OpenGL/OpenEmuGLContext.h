#pragma once

#include "Common/GraphicsContext.h"
#include "thin3d_create.h"
#include "GLRenderManager.h"

#include "Core/System.h"
#include "GPU/GPUState.h"

#include "Common/GPU/OpenGL/GLCommon.h"

class OpenEmuGLContext : public GraphicsContext {
public:
    OpenEmuGLContext();

    ~OpenEmuGLContext() override {Shutdown();};
    
    bool Init();
    bool Init(bool cache_context);
    
    void CreateDrawContext();
    void DestroyDrawContext();
    void ContextReset();
    void ContextDestroy();
    void GotBackbuffer();
    void LostBackbuffer();
    
    void Shutdown() override {
          DestroyDrawContext();
    }
    void Resize() override {}
    void SwapBuffers() {}
    
    void ThreadStart() override { renderManager_->ThreadStart(draw_); }
    bool ThreadFrame() override { return renderManager_->ThreadFrame(); }
    void ThreadEnd() override { renderManager_->ThreadEnd(); }
    void StopThread() override {
//        renderManager_->WaitUntilQueueIdle();
        renderManager_->StopThread();
    }
    
    void SetRenderTarget()  {
        extern GLuint g_defaultFBO;
        g_defaultFBO = RenderFBO;
    }
    void SetRenderFBO(GLuint FBO) {
        RenderFBO = FBO;
    }
    
    Draw::DrawContext *GetDrawContext() override { return draw_; }
    GPUCore GetGPUCore() { return GPUCORE_GLES; }
    const char *Ident() { return "OpenGL"; }

    static OpenEmuGLContext *CreateGraphicsContext();
    
protected:
    Draw::DrawContext *draw_ = nullptr;
    
private:
    GLRenderManager *renderManager_ = nullptr;
    GLuint RenderFBO = 0;
};

namespace OpenEmuCoreThread {
    extern OpenEmuGLContext *ctx;
} // namespace OpenEmu
