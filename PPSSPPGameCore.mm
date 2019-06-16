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

#include "gfx/OpenEmuGLContext.h"

#include "base/NativeApp.h"
#include "base/timeutil.h"

#include "Core/Core.h"
#include "Core/Config.h"
#include "Core/ConfigValues.h"
#include "Core/CoreParameter.h"
#include "Core/CoreTiming.h"
#include "Core/HLE/sceCtrl.h"
#include "Core/Host.h"
#include "Core/SaveState.h"
#include "Core/System.h"

#include "Common/GraphicsContext.h"
#include "Common/LogManager.h"

#include "thin3d/thin3d_create.h"
#include "thin3d/GLRenderManager.h"
#include "thin3d/DataFormatGL.h"


#define Option(_NAME_, _PREFKEY_) @{ OEGameCoreDisplayModeNameKey : _NAME_, OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, OEGameCoreDisplayModeStateKey : @NO, }
#define OptionIndented(_NAME_, _PREFKEY_) @{ OEGameCoreDisplayModeNameKey : _NAME_, OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, OEGameCoreDisplayModeStateKey : @NO, OEGameCoreDisplayModeIndentationLevelKey : @(1), }
#define OptionToggleable(_NAME_, _PREFKEY_) @{ OEGameCoreDisplayModeNameKey : _NAME_, OEGameCoreDisplayModePrefKeyNameKey : _PREFKEY_, OEGameCoreDisplayModeStateKey : @NO, OEGameCoreDisplayModeAllowsToggleKey : @YES, }
#define Label(_NAME_) @{ OEGameCoreDisplayModeLabelKey : _NAME_, }
#define SeparatorItem() @{ OEGameCoreDisplayModeSeparatorItemKey : [NSNull null],}

#define AUDIO_FREQ          44100
#define AUDIO_CHANNELS      2
#define AUDIO_SAMPLESIZE    sizeof(int16_t)

#define GRAPHIC_ORIG_W      480
#define GRAPHIC_ORIG_H      272
#define GRAPHIC_DOUBLE_W    960
#define GRAPHIC_DOUBLE_H    544
#define GRAPHIC_TRIPLE_W    1440
#define GRAPHIC_TRIPLE_H    816
#define GRAPHIC_FULLHD_W    1920
#define GRAPHIC_FULLHD_H    1088



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
    
    int displayMode;
    NSArray *_availableDisplayModes;

   OpenEmuGLContext *OEgraphicsContext;
}

- (NSString *)gameInternalName;

- (void)loadResolution;
- (void)loadResolutionDefault;
- (void)changeResolution:(NSString *)resolution;


@end

PPSSPPGameCore *_current = 0;

@implementation PPSSPPGameCore


- (instancetype)init
{
    (self = [super init]);
    
    _current = self;
    
    return self;
}

# pragma mark - Display Mode

/**
 *
 * return the list of Display Mode
 */
- (NSArray <NSDictionary <NSString *, id> *> *)displayModes
{
    if(_availableDisplayModes == nil || _availableDisplayModes.count == 0) {
        _availableDisplayModes = [NSArray array];
        
        NSArray <NSDictionary <NSString *, id> *> *availableModesWithDefault =
        @[
          Option(@"Original", @"resolution"),
          Option(@"2x",       @"resolution"),
          Option(@"HD",       @"resolution"),
          Option(@"Full HD",  @"resolution")
          ];
          
        
//        if (![self gameHasInternalResolution])
//            availableModesWithDefault = [availableModesWithDefault subarrayWithRange:NSMakeRange(1, availableModesWithDefault.count - 1)];
        
        _availableDisplayModes = availableModesWithDefault;
    }
    
    return _availableDisplayModes;
}


/**
 *
 * set the display Mode for the current game
 */
- (void)changeDisplayWithMode:(NSString *)displayMode
{

    // NOTE: This is a more complex implementation to serve as an example for handling submenus,
    // toggleable options and multiple groups of mutually exclusive options.
 
    if (_availableDisplayModes.count == 0)
        [self displayModes];
    
    // First check if 'displayMode' is toggleable and grab its preference key
    BOOL isDisplayModeToggleable, isValidDisplayMode;
    NSString *displayModePrefKey;
    for (NSDictionary *modeDict in _availableDisplayModes)
    {
        NSString *mode = modeDict[OEGameCoreDisplayModeNameKey];
        if ([mode isEqualToString:displayMode])
        {
            displayModePrefKey = modeDict[OEGameCoreDisplayModePrefKeyNameKey];
            isDisplayModeToggleable = [modeDict[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
            isValidDisplayMode = YES;
            break;
        }
        // Submenu Items
        for (NSDictionary *subModeDict in modeDict[OEGameCoreDisplayModeGroupItemsKey])
        {
            NSString *subMode = subModeDict[OEGameCoreDisplayModeNameKey];
            if ([subMode isEqualToString:displayMode])
            {
                displayModePrefKey = subModeDict[OEGameCoreDisplayModePrefKeyNameKey];
                isDisplayModeToggleable = [subModeDict[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
                isValidDisplayMode = YES;
                break;
            }
        }
    }
    
    // Disallow a 'displayMode' not found in _availableDisplayModes
    if (!isValidDisplayMode)
        return;
    
    
    NSMutableArray *tempOptionsArray = [NSMutableArray array];
    NSMutableArray *tempSubOptionsArray = [NSMutableArray array];
    NSString *mode, *pref, *label;
    BOOL isToggleable, isSelected;
    NSInteger indentationLevel;
    
    
    // Handle option state changes
    for (NSDictionary *optionDict in _availableDisplayModes)
    {
        mode             =  optionDict[OEGameCoreDisplayModeNameKey];
        pref             =  optionDict[OEGameCoreDisplayModePrefKeyNameKey];
        isToggleable     = [optionDict[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
        isSelected       = [optionDict[OEGameCoreDisplayModeStateKey] boolValue];
        indentationLevel = [optionDict[OEGameCoreDisplayModeIndentationLevelKey] integerValue] ?: 0;
        
        if (optionDict[OEGameCoreDisplayModeSeparatorItemKey])
        {
            [tempOptionsArray addObject:SeparatorItem()];
            continue;
        }
        else if (optionDict[OEGameCoreDisplayModeLabelKey])
        {
            label = optionDict[OEGameCoreDisplayModeLabelKey];
            [tempOptionsArray addObject:Label(label)];
            continue;
        }
        // Mutually exclusive option state change
        else if ([mode isEqualToString:displayMode] && !isToggleable)
            isSelected = YES;
        // Reset mutually exclusive options that are the same prefs group as 'displayMode'
        else if (!isDisplayModeToggleable && [pref isEqualToString:displayModePrefKey])
            isSelected = NO;
        // Toggleable option state change
        else if ([mode isEqualToString:displayMode] && isToggleable)
            isSelected = !isSelected;
        // Submenu group
        else if (optionDict[OEGameCoreDisplayModeGroupNameKey])
        {
            NSString *submenuTitle = optionDict[OEGameCoreDisplayModeGroupNameKey];
            // Submenu items
            for (NSDictionary *subOptionDict in optionDict[OEGameCoreDisplayModeGroupItemsKey])
            {
                mode             =  subOptionDict[OEGameCoreDisplayModeNameKey];
                pref             =  subOptionDict[OEGameCoreDisplayModePrefKeyNameKey];
                isToggleable     = [subOptionDict[OEGameCoreDisplayModeAllowsToggleKey] boolValue];
                isSelected       = [subOptionDict[OEGameCoreDisplayModeStateKey] boolValue];
                indentationLevel = [subOptionDict[OEGameCoreDisplayModeIndentationLevelKey] integerValue] ?: 0;
                
                if (subOptionDict[OEGameCoreDisplayModeSeparatorItemKey])
                {
                    [tempSubOptionsArray addObject:SeparatorItem()];
                    continue;
                }
                else if (subOptionDict[OEGameCoreDisplayModeLabelKey])
                {
                    label = subOptionDict[OEGameCoreDisplayModeLabelKey];
                    [tempSubOptionsArray addObject:Label(label)];
                    continue;
                }
                // Mutually exclusive option state change
                else if ([mode isEqualToString:displayMode] && !isToggleable)
                    isSelected = YES;
                // Reset mutually exclusive options that are the same prefs group as 'displayMode'
                else if (!isDisplayModeToggleable && [pref isEqualToString:displayModePrefKey])
                    isSelected = NO;
                // Toggleable option state change
                else if ([mode isEqualToString:displayMode] && isToggleable)
                    isSelected = !isSelected;
                
                // Add the submenu option
                [tempSubOptionsArray addObject:@{ OEGameCoreDisplayModeNameKey             : mode,
                                                  OEGameCoreDisplayModePrefKeyNameKey      : pref,
                                                  OEGameCoreDisplayModeStateKey            : @(isSelected),
                                                  OEGameCoreDisplayModeIndentationLevelKey : @(indentationLevel),
                                                  OEGameCoreDisplayModeAllowsToggleKey     : @(isToggleable) }];
            }
            
            // Add the submenu group
            [tempOptionsArray addObject:@{ OEGameCoreDisplayModeGroupNameKey  : submenuTitle,
                                           OEGameCoreDisplayModeGroupItemsKey : [tempSubOptionsArray copy] }];
            [tempSubOptionsArray removeAllObjects];
            continue;
        }
        
        // Add the option
        [tempOptionsArray addObject:@{ OEGameCoreDisplayModeNameKey             : mode,
                                       OEGameCoreDisplayModePrefKeyNameKey      : pref,
                                       OEGameCoreDisplayModeStateKey            : @(isSelected),
                                       OEGameCoreDisplayModeIndentationLevelKey : @(indentationLevel),
                                       OEGameCoreDisplayModeAllowsToggleKey     : @(isToggleable) }];
    }
    
    // Set the new Resolution
    if ([displayModePrefKey isEqualToString:@"resolution"])
        [self changeResolution:displayMode];
    
    _availableDisplayModes = tempOptionsArray;
    
}

- (NSString *)gameInternalName
{
    NSString *title = [NSString stringWithUTF8String:_coreParam.fileToStart.c_str()];
    return title;
}

- (void)loadResolution
{
    // Only temporary, so core doesn't crash on an older OpenEmu version
    if (![self respondsToSelector:@selector(displayModeInfo)])
    {
        [self loadResolutionDefault];
    }
    // No previous Resolution saved, set a default
    else if (self.displayModeInfo[@"resolution"] == nil)
    {
        [self loadResolutionDefault];
    }
    else
    {
        NSString *lastResolution = self.displayModeInfo[@"resolution"];
       
        [self changeDisplayWithMode:lastResolution];
    }
}

- (void)loadResolutionDefault
{
    [self changeDisplayWithMode:@"Original"];
}

- (void)changeResolution:(NSString *)resolution
{
    NSDictionary <NSString *, NSString *> *ResolutionNames =
    @{
      @"Original"   : @"Original",
      @"2x"         : @"2x",
      @"HD"         : @"HD",
      @"Full HD"    : @"Full HD",
      };
    
    resolution = ResolutionNames[resolution];
    
    if ([resolution isEqualToString:@"2x"])
    {
        _coreParam.renderWidth  = GRAPHIC_DOUBLE_W;
        _coreParam.renderHeight = GRAPHIC_DOUBLE_H;
        _coreParam.pixelWidth   = GRAPHIC_DOUBLE_W;
        _coreParam.pixelHeight  = GRAPHIC_DOUBLE_H;
    }
    else if ([resolution isEqualToString:@"HD"])
    {
        _coreParam.renderWidth  = GRAPHIC_TRIPLE_W;
        _coreParam.renderHeight = GRAPHIC_TRIPLE_H;
        _coreParam.pixelWidth   = GRAPHIC_TRIPLE_W;
        _coreParam.pixelHeight  = GRAPHIC_TRIPLE_H;
    }
    else if ([resolution isEqualToString:@"Full HD"])
    {
        _coreParam.renderWidth  = GRAPHIC_FULLHD_W;
        _coreParam.renderHeight = GRAPHIC_FULLHD_H;
        _coreParam.pixelWidth   = GRAPHIC_FULLHD_W;
        _coreParam.pixelHeight  = GRAPHIC_FULLHD_H;
        
    }
    else
        _coreParam.renderWidth  = GRAPHIC_ORIG_W;
        _coreParam.renderHeight = GRAPHIC_ORIG_H;
        _coreParam.pixelWidth   = GRAPHIC_ORIG_W;
        _coreParam.pixelHeight  = GRAPHIC_ORIG_H;
    
    [self resetEmulation];
    return;
    
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

    LogManager::Init();

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

    
    _coreParam.cpuCore      = CPUCore::JIT;
    _coreParam.gpuCore      = GPUCORE_GLES;
    _coreParam.enableSound  = true;
    _coreParam.fileToStart  = romURL.fileSystemRepresentation;
    _coreParam.mountIso     = "";
    _coreParam.startBreak  = false;
    _coreParam.printfEmuLog = false;
    _coreParam.headLess     = false;

    [self loadResolution];
    
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
        _coreParam.thin3d = OEgraphicsContext ? OEgraphicsContext->GetDrawContext() : nullptr;
       
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
    return OEIntSizeMake(_coreParam.pixelWidth, _coreParam.pixelHeight);
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
    SaveState::Save(fileName.fileSystemRepresentation, _OESaveStateCallback, (__bridge_retained void *)[block copy]);
}

- (void)loadStateFromFileAtPath:(NSString *)fileName completionHandler:(void (^)(BOOL, NSError *))block
{
    SaveState::Load(fileName.fileSystemRepresentation, _OELoadStateCallback, (__bridge_retained void *)[block copy]);
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
