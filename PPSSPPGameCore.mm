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

#import "PPSSPPGameCore.h"
#import <OpenEmuBase/OERingBuffer.h>
//#import <OpenGL/gl.h>

#include "Core/CoreParameter.h"
#include "Core/System.h"
#include "Core/Host.h"
#include "Core/Core.h"
#include "Core/CoreTiming.h"
#include "Core/MIPS/MIPS.h"
#include "Core/Config.h"

//#include "gfx_es2/gl_state.h"

//#include "GPU/GPUState.h"

#include "base/NativeApp.h"

#include <string>

#define SAMPLERATE 44000
#define SIZESOUNDBUFFER 44000 / 60 * 4

@interface PPSSPPGameCore () <OEPSPSystemResponderClient>
{
    uint16_t *soundBuffer;
    CoreParameter coreParam;
}
@end

@implementation PPSSPPGameCore

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    g_Config.Load();

    std::string *fileToStart = new std::string([path UTF8String]);
	coreParam.cpuCore = CPU_JIT;
	coreParam.gpuCore = GPU_GLES;
	coreParam.enableSound = true;
	coreParam.fileToStart = *fileToStart;
	coreParam.mountIso = "";
	coreParam.startPaused = false;
	coreParam.enableDebugging = false;
	coreParam.printfEmuLog = false;
	coreParam.headLess = false;
    coreParam.disableG3Dlog = false;

    coreParam.renderWidth = 480;
	coreParam.renderHeight = 272;
	coreParam.outputWidth = 480;
	coreParam.outputHeight = 272;
	coreParam.pixelWidth = 480;
	coreParam.pixelHeight = 272;

    return YES;
}

- (void)setupEmulation
{
    soundBuffer = (uint16_t *)malloc(SIZESOUNDBUFFER * sizeof(uint16_t));
    memset(soundBuffer, 0, SIZESOUNDBUFFER * sizeof(uint16_t));

    NativeInit(0, nil, nil, nil, nil);
}

- (void)startEmulation
{
    if(!isRunning)
    {
        [super startEmulation];
    }
}

- (void)stopEmulation
{
    NativeShutdownGraphics();
    NativeShutdown();

    [super stopEmulation];
}

- (void)resetEmulation
{
    
}

- (void)pauseEmulation:(id)sender
{

}
- (void)executeFrame
{
    if(!PSP_IsInited())
    {
        //CheckGLExtensions();

        std::string error_string;
        if(!PSP_Init(coreParam, &error_string))
        {
            NSLog(@"ERROR: %s", error_string.c_str());
        }

        globalUIState = UISTATE_INGAME;
        host->BootDone();
        host->UpdateDisassembly();

        NativeInitGraphics();
    }

    NativeRender();


    int blockTicks = usToCycles(1000000 / 10);

    while(coreState == CORE_RUNNING)
    {
		u64 nowTicks = CoreTiming::GetTicks();
		mipsr4k.RunLoopUntil(nowTicks + blockTicks);
	}
	// Hopefully coreState is now CORE_NEXTFRAME
	if(coreState == CORE_NEXTFRAME)
    {
		// set back to running for the next frame
		coreState = CORE_RUNNING;
    }

    //glstate.viewport.set(0, 0, 480, 272);
	//glstate.viewport.restore();
    
    int samplesWritten = NativeMix((short *)soundBuffer, SAMPLERATE / 60);
    [[self ringBufferAtIndex:0] write:soundBuffer maxLength:sizeof(uint16_t) * samplesWritten * 2];
}

# pragma mark - Video

- (BOOL)rendersToOpenGL
{
    return YES;
}

- (OEIntSize)bufferSize
{
    return OEIntSizeMake(480, 272);
}

- (OEIntSize)aspectSize
{
    return OEIntSizeMake(16, 9);
}

# pragma mark - Audio

- (NSUInteger)channelCount
{
    return 2;
}

- (double)audioSampleRate
{
    return SAMPLERATE;
}

# pragma mark - Save States

- (BOOL)loadStateFromFileAtPath:(NSString *)fileName
{
    return NO;
}

- (BOOL)saveStateToFileAtPath:(NSString *)fileName
{
    return NO;
}

# pragma mark - Input

- (oneway void)didMovePSPJoystickDirection:(OEPSPButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{

}

-(oneway void)didPushPSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{

}

- (oneway void)didReleasePSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{

}

@end
