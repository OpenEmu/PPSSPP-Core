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
#import <OpenGL/gl.h>

#include "base/NativeApp.h"

#include "Core/Config.h"
#include "Core/CoreParameter.h"
#include "Core/CoreTiming.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceDisplay.h"
#include "Core/Host.h"
#include "Core/SaveState.h"
#include "Core/System.h"

#define SAMPLERATE 44100
#define SIZESOUNDBUFFER 44100 / 30 * 4

@interface PPSSPPGameCore () <OEPSPSystemResponderClient>
{
    uint16_t *_soundBuffer;
    CoreParameter _coreParam;
    bool _isInitialized;
    bool _shouldReset;
    float _frameInterval;
}
@end

@implementation PPSSPPGameCore

- (id)init
{
    self = [super init];

    if(self)
    {
        _soundBuffer = (uint16_t *)malloc(SIZESOUNDBUFFER * sizeof(uint16_t));
        memset(_soundBuffer, 0, SIZESOUNDBUFFER * sizeof(uint16_t));
    }

    return self;
}

- (void)dealloc
{
    free(_soundBuffer);
}

# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    g_Config.Load("");
    __chdir([[self supportDirectoryPath] UTF8String]);

    NSString *directoryString      = [[self supportDirectoryPath] stringByAppendingString:@"/"];
    g_Config.currentDirectory      = [directoryString UTF8String];
    g_Config.externalDirectory     = [directoryString UTF8String];
    g_Config.memCardDirectory      = [directoryString UTF8String];
    g_Config.flashDirectory        = [directoryString UTF8String];
    g_Config.internalDataDirectory = [directoryString UTF8String];
    g_Config.iShowFPSCounter       = 1;

	_coreParam.cpuCore = CPU_JIT;
	_coreParam.gpuCore = GPU_GLES;
	_coreParam.enableSound = true;
	_coreParam.fileToStart = [path UTF8String];
	_coreParam.mountIso = "";
	_coreParam.startPaused = false;
	_coreParam.enableDebugging = false;
	_coreParam.printfEmuLog = false;
	_coreParam.headLess = false;
    _coreParam.disableG3Dlog = false;

    _coreParam.renderWidth = 480;
	_coreParam.renderHeight = 272;
	_coreParam.outputWidth = 480;
	_coreParam.outputHeight = 272;
	_coreParam.pixelWidth = 480;
	_coreParam.pixelHeight = 272;

    return YES;
}

- (void)stopEmulation
{
    // We need a OpenGL context here, because PPSSPP cleans up framebuffers at this point
    [[self renderDelegate] willRenderOnAlternateThread];
    [[self renderDelegate] startRenderingOnAlternateThread];
    PSP_Shutdown();

    NativeShutdownGraphics();
    NativeShutdown();

    [super stopEmulation];
}

- (void)resetEmulation
{
    _shouldReset = YES;
}

- (void)executeFrame
{
    if(!_isInitialized)
    {
        // This is where PPSSPP will look for ppge_atlas.zim
        NSString *resourcePath = [[[[self owner] bundle] resourcePath] stringByAppendingString:@"/"];
        
        NativeInit(0, nil, nil, [resourcePath UTF8String], nil);
        NativeInitGraphics();
    }

    if(_shouldReset)
        PSP_Shutdown();

    if(!_isInitialized || _shouldReset)
    {
        _isInitialized = YES;
        _shouldReset = NO;

        std::string error_string;
        if(!PSP_Init(_coreParam, &error_string))
            NSLog(@"ERROR: %s", error_string.c_str());

        host->BootDone();
		host->UpdateDisassembly();
    }

    NativeRender();

    float vps, fps;
    __DisplayGetFPS(&vps, &_frameInterval, &fps);

    int samplesWritten = NativeMix((short *)_soundBuffer, SAMPLERATE / _frameInterval);
    [[self ringBufferAtIndex:0] write:_soundBuffer maxLength:sizeof(uint16_t) * samplesWritten * 2];

    glFlushRenderAPPLE();
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

- (NSTimeInterval)frameInterval
{
    return _frameInterval ?: 60;
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

static void _OESaveStateCallback(bool status, void *cbUserData)
{
    void (^block)(BOOL, NSError *) = (__bridge_transfer void(^)(BOOL, NSError *))cbUserData;
    
    block(status, nil);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    SaveState::Save([fileName UTF8String], _OESaveStateCallback, (__bridge_retained void *)[block copy]);
    SaveState::Process();
}


- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    SaveState::Load([fileName UTF8String], _OESaveStateCallback, (__bridge_retained void *)[block copy]);
    SaveState::Process();
}

# pragma mark - Input

const int buttonMap[] = { CTRL_UP, CTRL_DOWN, CTRL_LEFT, CTRL_RIGHT, 0, 0, 0, 0, CTRL_TRIANGLE, CTRL_CIRCLE, CTRL_CROSS, CTRL_SQUARE, CTRL_LTRIGGER, CTRL_RTRIGGER, CTRL_START, CTRL_SELECT };

- (oneway void)didMovePSPJoystickDirection:(OEPSPButton)button withValue:(CGFloat)value forPlayer:(NSUInteger)player
{
    if(button == OEPSPAnalogUp || button == OEPSPAnalogDown)
        __CtrlSetAnalogY(button == OEPSPAnalogUp ? value : -value);
    else
        __CtrlSetAnalogX(button == OEPSPAnalogRight ? value : -value);
}

-(oneway void)didPushPSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{
    __CtrlButtonDown(buttonMap[button]);
}

- (oneway void)didReleasePSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{
    __CtrlButtonUp(buttonMap[button]);
}

@end
