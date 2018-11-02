#include "OpenEmuGLContext.h"

#include "Common/Log.h"
#include "Core/Config.h"
#include "Core/System.h"
#include "Core/ConfigValues.h"
#include "GPU/GPUInterface.h"
#include "gfx_es2/gpu_features.h"

//Set functions in PPSSPP GLRenderManager
static void context_SwapBuffer(){ ((OpenEmuGLContext *)OpenEmuCoreThread::ctx)->SwapBuffers(); }

bool OpenEmuGLContext::Init(bool cache_context) {
    return true;
}

void OpenEmuGLContext::ContextReset() {
    INFO_LOG(G3D, "Context reset");
    
    DestroyDrawContext();
    
    if (!draw_) {
        CreateDrawContext();
    }
    
    GotBackbuffer();
    
    if (gpu) {
        gpu->DeviceRestore();
    }
}

void OpenEmuGLContext::ContextDestroy() {
    INFO_LOG(G3D, "Context destroy");
    
    LostBackbuffer();
    
    gpu->DeviceLost();
    
    Shutdown();
}

void OpenEmuGLContext::GotBackbuffer() { draw_->HandleEvent(Draw::Event::GOT_BACKBUFFER, PSP_CoreParameter().pixelWidth, PSP_CoreParameter().pixelHeight); }

void OpenEmuGLContext::LostBackbuffer() { draw_->HandleEvent(Draw::Event::LOST_BACKBUFFER, -1, -1); }

OpenEmuGLContext *OpenEmuGLContext::CreateGraphicsContext() {
    OpenEmuGLContext *ctx;
    
    ctx = new OpenEmuGLContext();
    
    if (ctx->Init()) {
        
        return ctx;
    }
    delete ctx;

    return nullptr;
}

bool OpenEmuGLContext::Init() {
    if (!OpenEmuGLContext::Init(true)){
        return false;
    }
    
    g_Config.iGPUBackend = (int)GPUBackend::OPENGL;
    return true;
}

OpenEmuGLContext::OpenEmuGLContext() {
    OpenEmuGLContext::CreateDrawContext();
}

void OpenEmuGLContext::CreateDrawContext() {
    extern void CheckGLExtensions();
    
    CheckGLExtensions();
    
    draw_ = Draw::T3DCreateGLContext();
    renderManager_ = (GLRenderManager *)draw_->GetNativeObject(Draw::NativeObject::RENDER_MANAGER);
    
    PSP_CoreParameter().thin3d = draw_;
    bool success = draw_->CreatePresets();
    assert(success);
    
    renderManager_->SetSwapFunction([&]() {context_SwapBuffer();});
}

void OpenEmuGLContext::DestroyDrawContext() {
    OpenEmuGLContext::ContextDestroy();
    renderManager_ = nullptr;
}


