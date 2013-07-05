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

#include "Core/CoreParameter.h"
#include "Core/System.h"

#include <OpenGL/OpenGL.h>
#include <string>


@interface PPSSPPGameCore () <OEPSPSystemResponderClient>
{

}
@end

@implementation PPSSPPGameCore


# pragma mark - Execution

- (BOOL)loadFileAtPath:(NSString *)path
{
    std::string *fileToStart = new std::string([path UTF8String]);
    CoreParameter coreParam;
	coreParam.cpuCore = CPU_JIT;
	coreParam.gpuCore = GPU_GLES;
	coreParam.enableSound = YES;
	coreParam.fileToStart = *fileToStart;
	coreParam.mountIso = "";
	coreParam.startPaused = false;
	coreParam.enableDebugging = false;
	coreParam.printfEmuLog = false;
	coreParam.headLess = false;

    coreParam.renderWidth = 480;
	coreParam.renderHeight = 272;
	coreParam.outputWidth = 480;
	coreParam.outputHeight = 272;
	coreParam.pixelWidth = 480;
	coreParam.pixelHeight = 272;

    std::string error_string;
	if(!PSP_Init(coreParam, &error_string))
    {
		NSLog(@"ERROR: %s", error_string.c_str());
	}
    
    return NO;
}

- (void)setupEmulation
{

}

- (void)stopEmulation
{
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
    return 48000;
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
