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

#include "base/logging.h"
#include "base/NativeApp.h"

#include "Common/LogManager.h"

#include "Core/CoreTiming.h"
#include "Core/Host.h"
#include "Core/System.h"

#include "file/vfs.h"
#include "file/zip_read.h"

#include "gfx/gl_lost_manager.h"

#include "gfx_es2/fbo.h"
#include "gfx_es2/gl_state.h"

#include "GPU/GPUState.h"

#include "input/input_state.h"

#include "UI/OnScreenDisplay.h"

InputState input_state;
OnScreenMessages osm;

class AndroidLogger : public LogListener
{
public:
	void Log(LogTypes::LOG_LEVELS level, const char *msg)
	{
		switch (level)
		{
            case LogTypes::LVERBOSE:
            case LogTypes::LDEBUG:
            case LogTypes::LINFO:
                ILOG("%s", msg);
                break;
            case LogTypes::LERROR:
                ELOG("%s", msg);
                break;
            case LogTypes::LWARNING:
                WLOG("%s", msg);
                break;
            case LogTypes::LNOTICE:
            default:
                ILOG("%s", msg);
                break;
		}
	}
};

static AndroidLogger *logger = 0;

class NativeHost : public Host
{
public:
	NativeHost()
    {
		// hasRendered = false;
	}

	virtual void UpdateUI() {}

	virtual void UpdateMemView() {}
	virtual void UpdateDisassembly() {}

	virtual void SetDebugMode(bool mode) {}

	virtual bool InitGL(std::string *error_message) { return true; }
	virtual void ShutdownGL() {}

	virtual void InitSound(PMixer *mixer);
	virtual void UpdateSound() {}
	virtual void ShutdownSound();

	// this is sent from EMU thread! Make sure that Host handles it properly!
	virtual void BootDone() {}

	virtual bool IsDebuggingEnabled() { return false; }
	virtual bool AttemptLoadSymbolMap() { return false; }
	virtual void ResetSymbolMap() {}
	virtual void AddSymbol(std::string name, u32 addr, u32 size, int type=0) {}
	virtual void SetWindowTitle(const char *message) {}
};

static PMixer *g_mixer = 0;

void NativeHost::InitSound(PMixer *mixer)
{
    g_mixer = mixer;
}

void NativeHost::ShutdownSound()
{
    g_mixer = 0;
}

int NativeMix(short *audio, int num_samples)
{
	if(g_mixer)
		num_samples = g_mixer->Mix(audio, num_samples);
    else
		memset(audio, 0, num_samples * 2 * sizeof(short));

	return num_samples;
}

void NativeInit(int argc, const char *argv[], const char *savegame_directory, const char *external_directory, const char *installID)
{
    host = new NativeHost;

    logger = new AndroidLogger();

	LogManager::Init();
	LogManager *logman = LogManager::GetInstance();
	ILOG("Logman: %p", logman);

    LogTypes::LOG_LEVELS logLevel = LogTypes::LINFO;
	for(int i = 0; i < LogTypes::NUMBER_OF_LOGS; i++)
	{
		LogTypes::LOG_TYPE type = (LogTypes::LOG_TYPE)i;
        logman->SetLogLevel(type, logLevel);
    }

    VFSRegister("", new DirectoryAssetReader(external_directory));
}

void NativeInitGraphics()
{
    // Save framebuffer to later be bound again
    glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &framebuffer);

    gl_lost_manager_init();
}

void NativeRender()
{
	glstate.Restore();

    ReapplyGfxState();

    s64 blockTicks = usToCycles(1000000 / 10);
    while(coreState == CORE_RUNNING)
    {
		PSP_RunLoopFor((int)blockTicks);
	}

	// Hopefully coreState is now CORE_NEXTFRAME
	if(coreState == CORE_NEXTFRAME)
    {
		// set back to running for the next frame
		coreState = CORE_RUNNING;
    }
}

void NativeUpdate(InputState &input) {}

void NativeShutdownGraphics()
{
    gl_lost_manager_shutdown();
}

void NativeShutdown()
{
    delete host;
    host = 0;

    LogManager::Shutdown();
}

void OnScreenMessages::Show(const std::string &message, float duration_s, uint32_t color, int icon, bool checkUnique) {}
