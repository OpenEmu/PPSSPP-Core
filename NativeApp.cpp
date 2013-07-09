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

#include "gfx_es2/glsl_program.h"
#include "gfx_es2/gl_state.h"
#include "math/lin/matrix4x4.h"
#include "base/NativeApp.h"
#include "base/logging.h"
#include "UI/OnScreenDisplay.h"
#include "input/input_state.h"
#include "Core/Host.h"
#include "Common/LogManager.h"
#include "GPU/GPUState.h"

InputState input_state;
OnScreenMessages osm;

static PMixer *g_mixer = 0;

static GLSLProgram *glslModulate;

static const char modulate_fs[] =
"#ifdef GL_ES\n"
"precision lowp float;\n"
"#endif\n"
"uniform sampler2D sampler0;\n"
"varying vec2 v_texcoord0;\n"
"varying vec4 v_color;\n"
"void main() {\n"
"  gl_FragColor = texture2D(sampler0, v_texcoord0) * v_color;\n"
"}\n";

static const char modulate_vs[] =
"attribute vec4 a_position;\n"
"attribute vec4 a_color;\n"
"attribute vec2 a_texcoord0;\n"
"uniform mat4 u_worldviewproj;\n"
"varying vec2 v_texcoord0;\n"
"varying vec4 v_color;\n"
"void main() {\n"
"  v_texcoord0 = a_texcoord0;\n"
"  v_color = a_color;\n"
"  gl_Position = u_worldviewproj * a_position;\n"
"}\n";

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
    {
		num_samples = g_mixer->Mix(audio, num_samples);
	}
    else
    {
		memset(audio, 0, num_samples * 2 * sizeof(short));
	}

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

}

void NativeInitGraphics()
{
    CheckGLExtensions();

    gl_lost_manager_init();

    glslModulate = glsl_create_source(modulate_vs, modulate_fs);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    glstate.viewport.set(0, 0, 480, 272);
}

void NativeRender()
{
	glstate.depthWrite.set(GL_TRUE);
	glstate.colorMask.set(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);

	// Clearing the screen at the start of the frame is an optimization for tiled mobile GPUs, as it then doesn't need to keep it around between frames.
	glClearColor(0,0,0,1);
	glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

	glstate.viewport.set(0, 0, 480, 272);
	glstate.Restore();

	Matrix4x4 ortho;
	ortho.setOrtho(0.0f, 480, 272, 0.0f, -1.0f, 1.0f);
	glsl_bind(glslModulate);
	glUniformMatrix4fv(glslModulate->u_worldviewproj, 1, GL_FALSE, ortho.getReadPtr());

    ReapplyGfxState();

}

void NativeUpdate(InputState &input)
{

}

void NativeShutdownGraphics()
{
    gl_lost_manager_shutdown();
}

void NativeShutdown()
{
    delete host;
    host = 0;
}

void OnScreenMessages::Show(const std::string &message, float duration_s, uint32_t color, int icon, bool checkUnique)
{
}
