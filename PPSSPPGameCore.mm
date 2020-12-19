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

#include "Common/GPU/OpenGL/OpenEmuGLContext.h"

#include "System/NativeApp.h"
//#include "base/timeutil.h"

#define ExceptionInfo PPSSPPExceptionInfo
#include "Core/Core.h"
#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/CoreParameter.h"
#include "Core/CoreTiming.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/HLE/sceUtility.h"
#include "Core/Host.h"
#include "Core/SaveState.h"
#include "Core/System.h"
#undef ExceptionInfo

#include "Common/GraphicsContext.h"
#include "Common/LogManager.h"

#include "thin3d_create.h"
#include "GLRenderManager.h"
#include "DataFormatGL.h"

#define AUDIO_FREQ          44100
#define AUDIO_CHANNELS      2
#define AUDIO_SAMPLESIZE    sizeof(int16_t)



namespace SaveState {
    struct SaveStart {
        void DoState(PointerWrap &p);
    };
} // namespace SaveState

namespace OpenEmuCoreThread {
    enum class EmuThreadState {
        DISABLED,
        START_REQUESTED,
        RUNNING,
        PAUSE_REQUESTED,
        PAUSED,
        QUIT_REQUESTED,
        STOPPED,
    };
} //namespace OpenEmuThreadCore

void NativeSetThreadState(OpenEmuCoreThread::EmuThreadState threadState);

@interface PPSSPPGameCore () <OEPSPSystemResponderClient, OEAudioBuffer>
{
    CoreParameter _coreParam;
    bool _isInitialized;
    bool _shouldReset;

   OpenEmuGLContext *OEgraphicsContext;
}
@end

PPSSPPGameCore *_current = 0;

@implementation PPSSPPGameCore


- (instancetype)init
{
    (self = [super init]);
    
    _current = self;
    
    return self;
}
# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path error:(NSError **)error
{
    NSURL *romURL = [NSURL fileURLWithPath:path];
    NSURL *resourceURL = self.owner.bundle.resourceURL;
    NSURL *supportDirectoryURL = [NSURL fileURLWithPath:self.supportDirectoryPath isDirectory:YES];

    // Copy over font files if needed
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSURL *fontSourceDirectory = [resourceURL URLByAppendingPathComponent:@"flash0/font" isDirectory:YES];
    NSURL *fontDestinationDirectory = [supportDirectoryURL URLByAppendingPathComponent:@"font" isDirectory:YES];
    NSArray *fontFiles = [fileManager contentsOfDirectoryAtURL:fontSourceDirectory includingPropertiesForKeys:@[NSURLNameKey] options:0 error:nil];
    [fileManager createDirectoryAtURL:fontDestinationDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    for(NSURL *fontURL in fontFiles)
    {
        NSURL *destinationFontURL = [fontDestinationDirectory URLByAppendingPathComponent:fontURL.lastPathComponent];

        [fileManager copyItemAtURL:fontURL toURL:destinationFontURL error:nil];
    }

    LogManager::Init(NULL);

    g_Config.Load("");

    // Force a trailing forward slash that PPSSPP requires
    NSString *directoryString      = [supportDirectoryURL.path stringByAppendingString:@"/"];
    //NSURL *directoryURL3            = [supportDirectoryURL URLByAppendingPathComponent:@"/" isDirectory:YES];
    g_Config.currentDirectory      = directoryString.fileSystemRepresentation;
    g_Config.externalDirectory     = directoryString.fileSystemRepresentation;
    g_Config.memStickDirectory     = directoryString.fileSystemRepresentation;
    g_Config.flash0Directory       = directoryString.fileSystemRepresentation;
    g_Config.internalDataDirectory = directoryString.fileSystemRepresentation;
    g_Config.iGPUBackend           = (int)GPUBackend::OPENGL;
    g_Config.bHideStateWarnings    = false;
    g_Config.iLanguage             = PSP_SYSTEMPARAM_LANGUAGE_ENGLISH;
    
    _coreParam.cpuCore      = CPUCore::JIT;
    _coreParam.gpuCore      = GPUCORE_GLES;
    _coreParam.enableSound  = true;
    _coreParam.fileToStart  = romURL.fileSystemRepresentation;
    _coreParam.mountIso     = "";
    _coreParam.startBreak  = false;
    _coreParam.printfEmuLog = false;
    _coreParam.headLess     = false;

    _coreParam.renderWidth  = 480;
    _coreParam.renderHeight = 272;
    _coreParam.pixelWidth   = 480;
    _coreParam.pixelHeight  = 272;

    coreState = CORE_POWERUP;
    
    
    return true;
}

- (void)stopEmulation
{
    NativeSetThreadState(OpenEmuCoreThread::EmuThreadState::PAUSE_REQUESTED);

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
        // This is where PPSSPP will look for ppge_atlas.zim, requires trailing forward slash
        NSString *resourcePath = [self.owner.bundle.resourcePath stringByAppendingString:@"/"];

        OEgraphicsContext = OpenEmuGLContext::CreateGraphicsContext();
        
        NativeInit(0, nil, nil, resourcePath.fileSystemRepresentation, nil);

        OEgraphicsContext->InitFromRenderThread(nullptr);
        
        _coreParam.graphicsContext = OEgraphicsContext;
       
        NativeInitGraphics(OEgraphicsContext);
    }

    if(_shouldReset)
    {
        NativeSetThreadState(OpenEmuCoreThread::EmuThreadState::PAUSE_REQUESTED);
        PSP_Shutdown();
    }

    if(!_isInitialized || _shouldReset)
    {
        _isInitialized = YES;
        _shouldReset = NO;

        std::string error_string;
        if(!PSP_Init(_coreParam, &error_string))
            NSLog(@"[PPSSPP] ERROR: %s", error_string.c_str());

        host->BootDone();
		host->UpdateDisassembly();
        
        //Start the Emulator Thread
        NativeSetThreadState(OpenEmuCoreThread::EmuThreadState::START_REQUESTED);
        
    } else {
        //If Fast forward rate is detected, unthrottle the rndering
        PSP_CoreParameter().unthrottle = (self.rate > 1) ? true : false;

        //Let PPSSPP Core run a loop and return
        UpdateRunLoop();
    }
}
# pragma mark - Video

- (OEGameCoreRendering)gameCoreRendering
{
    return OEGameCoreRenderingOpenGL2Video;
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
    return 59.94;
}

# pragma mark - Audio

- (NSUInteger)channelCount
{
    return AUDIO_CHANNELS;
}

- (double)audioSampleRate
{
    return AUDIO_FREQ;
}

- (id<OEAudioBuffer>)audioBufferAtIndex:(NSUInteger)index
{
    return self;
}

- (NSUInteger)read:(void *)buffer maxLength:(NSUInteger)len
{
    NativeMix((short *)buffer, (int)(len / (AUDIO_CHANNELS * sizeof(uint16_t))));
    return len;
}

- (NSUInteger)write:(const void *)buffer maxLength:(NSUInteger)length
{
    return 0;
}

- (NSUInteger)length
{
    return AUDIO_FREQ / 15;
}

# pragma mark - Save States

static void _OESaveStateCallback(SaveState::Status status, std::string message, void *cbUserData)
{
    void (^block)(BOOL, NSError *) = (__bridge_transfer void(^)(BOOL, NSError *))cbUserData;

    [_current endPausedExecution];
    
    block((status != SaveState::Status::FAILURE), nil);
}

static void _OELoadStateCallback(SaveState::Status status, std::string message, void *cbUserData)
{
    void (^block)(BOOL, NSError *) = (__bridge_transfer void(^)(BOOL, NSError *))cbUserData;

    //Unpause the EmuThread by requesting it to start again
    NativeSetThreadState(OpenEmuCoreThread::EmuThreadState::START_REQUESTED);
    NSError *error = nil;
        
    if(status == SaveState::Status::WARNING) {
        error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:@{
            NSLocalizedDescriptionKey : NSLocalizedString(@"PPSSPP Save State Warning", @"PPSSPP Save State Warning description."),
            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:NSLocalizedString(@"This save state was created from a previous version of PPSSPP, or simulates over 4 hours of time played.\n\nSave states preserve bugs from old PPSSPP versions and states from long sessions can also expose bugs rarely seen on a real PSP.\n\nIt is recommended to \"clean load\" for less bugs:\n\n1. Save in-game (memory stick, not save state), then stop emulation.\n2. Go to OpenEmu > Preferences > Library, click \"Reset warnings\".\n3. Reopen your game and click \"No\" when prompted to \"Continue where you left off\".", @"PPSSPP Save State Warning.")]
        }];
    } else if(status == SaveState::Status::FAILURE) {
        error = [NSError errorWithDomain:OEGameCoreErrorDomain code:OEGameCoreCouldNotLoadStateError userInfo:@{
            NSLocalizedDescriptionKey : NSLocalizedString(@"The Save State failed to Load", @"PPSSPP Save State Failure description."),
            NSLocalizedRecoverySuggestionErrorKey : [NSString stringWithFormat:NSLocalizedString(@"Could not load Save State.", @"PPSSPP Save State Failure.")]
        }];
    }
    
    block((status == SaveState::Status::SUCCESS), error);
}

- (void)saveStateToFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    [self beginPausedExecution];
    SaveState::Save(fileName.fileSystemRepresentation,0, _OESaveStateCallback, (__bridge_retained void *)[block copy]);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    SaveState::Load(fileName.fileSystemRepresentation, 0,_OELoadStateCallback, (__bridge_retained void *)[block copy]);
    if(_isInitialized){
        //We need to pause our EmuThread so we don't try to process the save state in the middle of a Frame Render
        NativeSetThreadState(OpenEmuCoreThread::EmuThreadState::PAUSE_REQUESTED);

        SaveState::Process();
    }
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

- (oneway void)didPushPSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{
    __CtrlButtonDown(buttonMap[button]);
}

- (oneway void)didReleasePSPButton:(OEPSPButton)button forPlayer:(NSUInteger)player
{
    __CtrlButtonUp(buttonMap[button]);
}

@end
