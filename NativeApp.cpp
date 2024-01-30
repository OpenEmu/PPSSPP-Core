
/*
 Copyright (c) 2013, OpenEmu Team

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
     * Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.
     * Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.
     * Neither the name of the OpenEmu Team nor the
       names of its contributors may be used to endorse or promote products
       derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <atomic>
#include <thread>
#include "Thread/ThreadUtil.h"

#include "Common/LogManager.h"
#include "Common/CPUDetect.h"

#include "Core/Core.h"
#include "Core/Config.h"
#include "Core/CoreTiming.h"
#include "Core/System.h"
#include "Core/FrameTiming.h"
#include "Core/RetroAchievements.h"
#include "Core/Util/GameManager.h"
#include "Core/HLE/__sceAudio.h"
#include "UI/AudioCommon.h"
#include "Core/ThreadPools.h"
#include "Core/FileLoaders/DiskCachingFileLoader.h"

#include "File/VFS/VFS.h"
#include "File/VFS/DirectoryReader.h"

#include "Common/GPU/OpenGL/OpenEmuGLContext.h"
#include "Common/GPU/OpenGL/GLCommon.h"
#include "Common/GPU/thin3d.h"
#include "DataFormat.h"

#include "Common/GraphicsContext.h"
#include "GPU/GPUState.h"

#include "GPU/GPUState.h"
#include "GPU/GPUInterface.h"
#include "Common/GPU/ShaderTranslation.h"

#include "DataFormatGL.h"

#include "Common/Input/InputState.h"
#include "Common/System/System.h"

#include "UI/OnScreenDisplay.h"

#include <stdio.h>

inline const char *removePath(const char *str) {
	const char *slash = strrchr(str, '/');
	return slash ? (slash + 1) : str;
}

#ifdef _DEBUG
#define DLOG(...) {printf("D: %s:%i: ", removePath(__FILE__), __LINE__); printf("D: " __VA_ARGS__); printf("\n");}
#else
#define DLOG(...)
#endif
#define ILOG(...) {printf("I: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define WLOG(...) {printf("W: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define ELOG(...) {printf("E: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n");}
#define FLOG(...) {printf("F: %s:%i: ", removePath(__FILE__), __LINE__); printf(__VA_ARGS__); printf("\n"); Crash();}

KeyInput input_state;

ScreenManager *g_screenManager;
static Draw::DrawContext *g_draw;
static Draw::Pipeline *colorPipeline;
static Draw::Pipeline *texColorPipeline;
static bool restarting = false;

namespace OpenEmuCoreThread {
    OpenEmuGLContext *ctx;

    enum class EmuThreadState {
        DISABLED,
        START_REQUESTED,
        RUNNING,
        PAUSE_REQUESTED,
        PAUSED,
        QUIT_REQUESTED,
        STOPPED,
    };

    static std::thread emuThread;
    static bool threadStarted = false;
    static std::atomic<EmuThreadState> emuThreadState(EmuThreadState::DISABLED);

    static void EmuFrame() {

        ctx->SetRenderTarget();

        if (ctx->GetDrawContext()) {
            ctx->GetDrawContext()->BeginFrame(Draw::DebugFlags::NONE);
        }

        gpu->BeginHostFrame();

        coreState = CORE_RUNNING;
        PSP_RunLoopUntil(UINT64_MAX);

        gpu->EndHostFrame();

        if (ctx->GetDrawContext()) {
            ctx->GetDrawContext()->EndFrame();
        }
    }

    static void EmuThreadFunc() {
		SetCurrentThreadName("Emu");

        while (true) {
            switch ((EmuThreadState)emuThreadState) {
                case EmuThreadState::START_REQUESTED:
                    threadStarted = true;
                    emuThreadState = EmuThreadState::RUNNING;
                    /* fallthrough */
                case EmuThreadState::RUNNING:
                    EmuFrame();
                    break;
                case EmuThreadState::PAUSE_REQUESTED:
                    emuThreadState = EmuThreadState::PAUSED;
                    /* fallthrough */
                case EmuThreadState::PAUSED:
                    usleep(1000);
                    break;
                default:
                case EmuThreadState::QUIT_REQUESTED:
                    emuThreadState = EmuThreadState::STOPPED;
                    ctx->StopThread();
                    return;
            }
        }
    }

    void EmuThreadStart() {
        bool wasPaused = emuThreadState == EmuThreadState::PAUSED;
        emuThreadState = EmuThreadState::START_REQUESTED;

        if (!wasPaused) {
            ctx->ThreadStart();
            emuThread = std::thread(&EmuThreadFunc);
        }
    }

    void EmuThreadStop() {
        if (emuThreadState != EmuThreadState::RUNNING) {
            return;
        }

        emuThreadState = EmuThreadState::QUIT_REQUESTED;

        while (ctx->ThreadFrame()) {
            // Need to keep eating frames to allow the EmuThread to exit correctly.
            continue;
        }
        emuThread.join();
        emuThread = std::thread();
        ctx->ThreadEnd();
    }

    void EmuThreadPause() {
        if (emuThreadState != EmuThreadState::RUNNING) {
            return;
        }
        emuThreadState = EmuThreadState::PAUSE_REQUESTED;

        while (emuThreadState != EmuThreadState::PAUSED) {
            //We need to process frames until the thread Pauses give 10 ms between loops
            ctx->ThreadFrame();
            emuThreadState = EmuThreadState::PAUSE_REQUESTED;
            usleep(10000);
        }
    }

    static void EmuThreadJoin() {
        emuThread.join();
        emuThread = std::thread();
    }
}  // namespace OpenEmuCoreThread


// Here's where we store the OpenEmu framebuffer to bind for final rendering
int framebuffer = 0;

class AndroidLogger : public LogListener
{
public:
    void Log(const LogMessage &msg) override{};
};

static AndroidLogger *logger = 0;

int NativeMix(short *audio, int num_samples, int sampleRateHz)
{
    num_samples = __AudioMix(audio, num_samples, sampleRateHz);

	return num_samples;
}
bool CreateGlobalPipelines();

void NativeInit(int argc, const char *argv[], const char *savegame_directory, const char *external_directory, const char *cache_directory)
{
    g_VFS.Register("", new DirectoryReader(Path("assets/")));
    g_VFS.Register("", new DirectoryReader(Path(external_directory)));

    g_screenManager = new ScreenManager();
    SetGPUBackend(GPUBackend::OPENGL);
    
    ShaderTranslationInit();
    
    g_threadManager.Init(cpu_info.num_cores, cpu_info.logical_cpu_count);

    DiskCachingFileLoaderCache::SetCacheDir(g_Config.appCacheDirectory);
    
	LogManager *logman = LogManager::GetInstance();
	ILOG("Logman: %p", logman);

    LogLevel logLevel = LogLevel::LINFO;
	for(int i = 0; i < (int)LogType::NUMBER_OF_LOGS; i++)
	{
		LogType type = (LogType)i;
        logman->SetLogLevel(type, logLevel);
    }
    
    // Initialize retro achievements runtime.
    Achievements::Initialize();
    
    // Must be done restarting by now.
    restarting = false;
}

void NativeSetThreadState(OpenEmuCoreThread::EmuThreadState threadState)  {
    if(threadState == OpenEmuCoreThread::EmuThreadState::PAUSE_REQUESTED && OpenEmuCoreThread::threadStarted)
        OpenEmuCoreThread::EmuThreadPause();
    else if(threadState == OpenEmuCoreThread::EmuThreadState::START_REQUESTED && !OpenEmuCoreThread::threadStarted)
        OpenEmuCoreThread::EmuThreadStart();
    else
        OpenEmuCoreThread::emuThreadState = threadState;
}

bool NativeInitGraphics(GraphicsContext *graphicsContext)
{
    //Set the Core Thread graphics Context
    OpenEmuCoreThread::ctx = static_cast<OpenEmuGLContext*>(graphicsContext);

    // Save framebuffer and set ppsspp default graphics framebuffer object
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &framebuffer);
    OpenEmuCoreThread::ctx->SetRenderFBO(framebuffer);

    Core_SetGraphicsContext(OpenEmuCoreThread::ctx);
    g_draw = graphicsContext->GetDrawContext();

    CreateGlobalPipelines();

    if (gpu)
        gpu->DeviceRestore(g_draw);

    return true;
}

void NativeResized(){}

void NativeRender(GraphicsContext *ctx)
{
    if(OpenEmuCoreThread::emuThreadState == OpenEmuCoreThread::EmuThreadState::PAUSED)
        return;

    OpenEmuCoreThread::ctx->ThreadFrame();
    OpenEmuCoreThread::ctx->SwapBuffers();
}

void NativeUpdate() {}

bool CreateGlobalPipelines() {
    using namespace Draw;

    ShaderModule *vs_color_2d = g_draw->GetVshaderPreset(VS_COLOR_2D);
    ShaderModule *fs_color_2d = g_draw->GetFshaderPreset(FS_COLOR_2D);
    ShaderModule *vs_texture_color_2d = g_draw->GetVshaderPreset(VS_TEXTURE_COLOR_2D);
    ShaderModule *fs_texture_color_2d = g_draw->GetFshaderPreset(FS_TEXTURE_COLOR_2D);

    if (!vs_color_2d || !fs_color_2d || !vs_texture_color_2d || !fs_texture_color_2d) {
        ERROR_LOG(G3D, "Failed to get shader preset");
        return false;
    }

    //InputLayout *inputLayout = ui_draw2d.CreateInputLayout(g_draw);
    BlendState *blendNormal = g_draw->CreateBlendState({ true, 0xF, BlendFactor::SRC_ALPHA, BlendFactor::ONE_MINUS_SRC_ALPHA });
    DepthStencilState *depth = g_draw->CreateDepthStencilState({ false, false, Comparison::LESS });
    RasterState *rasterNoCull = g_draw->CreateRasterState({});

    // Release these now, reference counting should ensure that they get completely released
    // once we delete both pipelines.
   
    rasterNoCull->Release();
    blendNormal->Release();
    depth->Release();
    return true;
}


void NativeShutdownGraphics()
{
}

void NativeFrame(GraphicsContext *graphicsContext)
{
    g_screenManager->update();

    g_GameManager.Update();
    
    g_frameTiming.Reset(g_draw);

    g_draw->BeginFrame(Draw::DebugFlags::NONE);
    g_screenManager->render();
    
    g_draw->EndFrame();
}

void NativeSetRestarting() {
    restarting = true;
}

bool NativeIsRestarting() {
    return restarting;
}

void NativeShutdown()
{
    Achievements::Shutdown();

    if (g_screenManager) {
        g_screenManager->shutdown();
        delete g_screenManager;
        g_screenManager = nullptr;
    }

//    ShutdownWebServer();

#if PPSSPP_PLATFORM(ANDROID) || PPSSPP_PLATFORM(IOS)
    System_ExitApp();
#endif

//    g_PortManager.Shutdown();

    net::Shutdown();

    ShaderTranslationShutdown();

    // Avoid shutting this down when restarting core.
    if (!restarting)
        LogManager::Shutdown();

    if (logger) {
        delete logger;
        logger = nullptr;
    }

    g_threadManager.Teardown();
}

//void OnScreenMessages::Show(const std::string &text, float duration_s, uint32_t color, int icon, bool checkUnique, const char *id) {}

std::string System_GetProperty(SystemProperty prop) {
	switch (prop) {
        case SYSPROP_NAME:
            return "OpenEmu:";
         case SYSPROP_LANGREGION: {
               // Get user-preferred locale from OS
               setlocale(LC_ALL, "");
               std::string locale(setlocale(LC_ALL, NULL));
               // Set c and c++ strings back to POSIX
               std::locale::global(std::locale("POSIX"));
               if (!locale.empty()) {
                   if (locale.find("_", 0) != std::string::npos) {
                       if (locale.find(".", 0) != std::string::npos) {
                           return locale.substr(0, locale.find(".",0));
                       } else {
                           return locale;
                       }
                   }
               }
               return "en_US";
           }
        default:
            return "";
	}
}

std::vector<std::string> System_GetPropertyStringVec(SystemProperty prop) {
    return {};
}

int System_GetPropertyInt(SystemProperty prop) {
    switch (prop) {
        case SYSPROP_AUDIO_SAMPLE_RATE:
            return 44100;
        case SYSPROP_DISPLAY_REFRESH_RATE:
            return 60000;
        default:
            return -1;
    }
}

float System_GetPropertyFloat(SystemProperty prop) {
    switch (prop) {
    case SYSPROP_DISPLAY_REFRESH_RATE:
            return 59.94f;
    case SYSPROP_DISPLAY_SAFE_INSET_LEFT:
    case SYSPROP_DISPLAY_SAFE_INSET_RIGHT:
    case SYSPROP_DISPLAY_SAFE_INSET_TOP:
    case SYSPROP_DISPLAY_SAFE_INSET_BOTTOM:
        return 0.0f;
    default:
        return -1;
    }
}

bool System_GetPropertyBool(SystemProperty prop) {
    switch (prop) {
    case SYSPROP_HAS_BACK_BUTTON:
        return true;
    case SYSPROP_APP_GOLD:
#ifdef GOLD
        return true;
#else
        return false;
#endif
    default:
        return false;
    }
}

void System_Notify(SystemNotification notification) {
    
}

bool System_MakeRequest(SystemRequestType type, int requestId, const std::string &param1, const std::string &param2, int param3) {
    return false;
}

std::vector<std::string> System_GetCameraDeviceList() {
    return {};
}

void System_SendMessage(const char *command, const char *parameter) {
    return;
}

void System_PostUIMessage(const std::string &message, const std::string &param) {
    
}
