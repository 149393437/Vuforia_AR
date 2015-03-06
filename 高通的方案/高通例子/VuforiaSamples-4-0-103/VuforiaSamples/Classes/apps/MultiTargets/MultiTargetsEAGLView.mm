/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <sys/time.h>

#import <QCAR/QCAR.h>
#import <QCAR/State.h>
#import <QCAR/Tool.h>
#import <QCAR/Renderer.h>
#import <QCAR/TrackableResult.h>
#import <QCAR/VideoBackgroundConfig.h>
#import <QCAR/MultiTargetResult.h>

#import "MultiTargetsEAGLView.h"
#import "Texture.h"
#import "SampleApplicationUtils.h"
#import "SampleApplicationShaderUtils.h"
#import "Cube.h"
#import "BowlAndSpoonModel.h"


//******************************************************************************
// *** OpenGL ES thread safety ***
//
// OpenGL ES on iOS is not thread safe.  We ensure thread safety by following
// this procedure:
// 1) Create the OpenGL ES context on the main thread.
// 2) Start the QCAR camera, which causes QCAR to locate our EAGLView and start
//    the render thread.
// 3) QCAR calls our renderFrameQCAR method periodically on the render thread.
//    The first time this happens, the defaultFramebuffer does not exist, so it
//    is created with a call to createFramebuffer.  createFramebuffer is called
//    on the main thread in order to safely allocate the OpenGL ES storage,
//    which is shared with the drawable layer.  The render (background) thread
//    is blocked during the call to createFramebuffer, thus ensuring no
//    concurrent use of the OpenGL ES context.
//
//******************************************************************************


namespace {
    // --- Data private to this unit ---
    // Texture filenames
    const char* textureFilenames[] = {
        "TextureWireframe.png",
        "TextureBowlAndSpoon.png"
    };
    
    // Constants:
    const float kCubeScaleX = 120.0f * 0.75f / 2.0f;
    const float kCubeScaleY = 120.0f * 1.00f / 2.0f;
    const float kCubeScaleZ = 120.0f * 0.50f / 2.0f;
    
    const float kBowlScaleX = 120.0f * 0.15f;
    const float kBowlScaleY = 120.0f * 0.15f;
    const float kBowlScaleZ = 120.0f * 0.15f;
}


@interface MultiTargetsEAGLView (PrivateMethods)

- (void)initShaders;
- (void)createFramebuffer;
- (void)deleteFramebuffer;
- (void)setFramebuffer;
- (BOOL)presentFramebuffer;

@end


@implementation MultiTargetsEAGLView

// You must implement this method, which ensures the view's underlying layer is
// of type CAEAGLLayer
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}


//------------------------------------------------------------------------------
#pragma mark - Lifecycle

- (id)initWithFrame:(CGRect)frame appSession:(SampleApplicationSession *) app
{
    self = [super initWithFrame:frame];
    
    if (self) {
        vapp = app;
        // Enable retina mode if available on this device
        if (YES == [vapp isRetinaDisplay]) {
            [self setContentScaleFactor:2.0f];
        }
        
        // Load the augmentation textures
        for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
            augmentationTexture[i] = [[Texture alloc] initWithImageFile:[NSString stringWithCString:textureFilenames[i] encoding:NSASCIIStringEncoding]];
        }

        // Create the OpenGL ES context
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        // The EAGLContext must be set for each thread that wishes to use it.
        // Set it the first time this method is called (on the main thread)
        if (context != [EAGLContext currentContext]) {
            [EAGLContext setCurrentContext:context];
        }
        
        // Generate the OpenGL ES texture and upload the texture data for use
        // when rendering the augmentation
        for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
            GLuint textureID;
            glGenTextures(1, &textureID);
            [augmentationTexture[i] setTextureID:textureID];
            glBindTexture(GL_TEXTURE_2D, textureID);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, [augmentationTexture[i] width], [augmentationTexture[i] height], 0, GL_RGBA, GL_UNSIGNED_BYTE, (GLvoid*)[augmentationTexture[i] pngData]);
        }
        offTargetTrackingEnabled = NO;

        [self initShaders];
    }
    
    return self;
}


- (void)dealloc
{
    [self deleteFramebuffer];
    
    // Tear down context
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
    
    [context release];

    for (int i = 0; i < NUM_AUGMENTATION_TEXTURES; ++i) {
        [augmentationTexture[i] release];
    }

    [super dealloc];
}


- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  The render loop has
    // been stopped, so we now make sure all OpenGL ES commands complete before
    // we (potentially) go into the background
    if (context) {
        [EAGLContext setCurrentContext:context];
        glFinish();
    }
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Free easily
    // recreated OpenGL ES resources
    [self deleteFramebuffer];
    glFinish();
}

- (void) setOffTargetTrackingMode:(BOOL) enabled {
    offTargetTrackingEnabled = enabled;
}

//------------------------------------------------------------------------------
#pragma mark - UIGLViewProtocol methods

// Draw the current frame using OpenGL
//
// This method is called by QCAR when it wishes to render the current frame to
// the screen.
//
// *** QCAR will call this method periodically on a background thread ***
- (void)renderFrameQCAR
{
    [self setFramebuffer];
    
    // Clear color and depth buffer
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Begin QCAR rendering for this frame, retrieving the tracking state
    QCAR::State state = QCAR::Renderer::getInstance().begin();
    
    // Render the video background
    QCAR::Renderer::getInstance().drawVideoBackground();
    
    glEnable(GL_DEPTH_TEST);
    
    // We must detect if background reflection is active and adjust the culling direction.
    // If the reflection is active, this means the pose matrix has been reflected as well,
    // therefore standard counter clockwise face culling will result in "inside out" models.
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    if(QCAR::Renderer::getInstance().getVideoBackgroundConfig().mReflection == QCAR::VIDEO_BACKGROUND_REFLECTION_ON)
        glFrontFace(GL_CW);  //Front camera
    else
        glFrontFace(GL_CCW);   //Back camera
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    // Did we find any trackables this frame?
    if (state.getNumTrackableResults())
    {
        // Get the trackable:
        const QCAR::TrackableResult* result = NULL;
        int numResults = state.getNumTrackableResults();
        
        // Browse results searching for the MultiTargets
        for (int j=0; j<numResults; j++)
        {
            result = state.getTrackableResult(j);
            if (result->isOfType(QCAR::MultiTargetResult::getClassType()))
                break;
        }
        
        // If it was not found exit
        if (result == NULL)
        {
            // Clean up and leave
            glDisable(GL_BLEND);
            glDisable(GL_DEPTH_TEST);
            glDisable(GL_CULL_FACE);
            
            QCAR::Renderer::getInstance().end();
            [self presentFramebuffer];
            return;
        }
        
        
        QCAR::Matrix44F modelViewMatrix =
        QCAR::Tool::convertPose2GLMatrix(result->getPose());
        QCAR::Matrix44F modelViewProjection;
        SampleApplicationUtils::scalePoseMatrix(kCubeScaleX, kCubeScaleY, kCubeScaleZ,
                                     &modelViewMatrix.data[0]);
        SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0],
                                    &modelViewMatrix.data[0],
                                    &modelViewProjection.data[0]);
        
        glUseProgram(shaderProgramID);
        
        // Draw the cube:
        glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeVertices[0]);
        
        glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeNormals[0]);
        
        glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &cubeTexCoords[0]);
        
        glEnableVertexAttribArray(vertexHandle);
        
        glEnableVertexAttribArray(normalHandle);
        
        glEnableVertexAttribArray(textureCoordHandle);
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, [augmentationTexture[0] textureID]);
        glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                           (GLfloat*)&modelViewProjection.data[0] );
        glUniform1i(texSampler2DHandle, 0 /*GL_TEXTURE0*/);
        glDrawElements(GL_TRIANGLES, NUM_CUBE_INDEX, GL_UNSIGNED_SHORT,
                       (const GLvoid*) &cubeIndices[0]);
        glDisable(GL_CULL_FACE);
        
        // Draw the bowl:
        modelViewMatrix = QCAR::Tool::convertPose2GLMatrix(result->getPose());
        
        // Remove the following line to make the bowl stop spinning:
        [self animateBowl: &modelViewMatrix];
        
        SampleApplicationUtils::translatePoseMatrix(0.0f, -0.50f*120.0f, 1.35f*120.0f,
                                         &modelViewMatrix.data[0]);
        SampleApplicationUtils::rotatePoseMatrix(-90.0f, 1.0f, 0, 0,
                                      &modelViewMatrix.data[0]);
        
        SampleApplicationUtils::scalePoseMatrix(kBowlScaleX, kBowlScaleY, kBowlScaleZ,
                                     &modelViewMatrix.data[0]);
        SampleApplicationUtils::multiplyMatrix(&vapp.projectionMatrix.data[0],
                                    &modelViewMatrix.data[0],
                                    &modelViewProjection.data[0]);
        
        glVertexAttribPointer(vertexHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &objectVertices[0]);
        glVertexAttribPointer(normalHandle, 3, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &objectNormals[0]);
        glVertexAttribPointer(textureCoordHandle, 2, GL_FLOAT, GL_FALSE, 0,
                              (const GLvoid*) &objectTexCoords[0]);
        
        glBindTexture(GL_TEXTURE_2D, [augmentationTexture[1] textureID]);
        
        glUniformMatrix4fv(mvpMatrixHandle, 1, GL_FALSE,
                           (GLfloat*)&modelViewProjection.data[0] );
        
        glDrawElements(GL_TRIANGLES, NUM_OBJECT_INDEX, GL_UNSIGNED_SHORT,
                       (const GLvoid*) &objectIndices[0]);
        
        // Check for GL error
        SampleApplicationUtils::checkGlError("EAGLView renderFrameQCAR");
        
        glDisableVertexAttribArray(vertexHandle);
        glDisableVertexAttribArray(normalHandle);
        glDisableVertexAttribArray(textureCoordHandle);
    }
    
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    
    QCAR::Renderer::getInstance().end();
    [self presentFramebuffer];
}

//------------------------------------------------------------------------------
#pragma mark - OpenGL ES management

- (void)initShaders
{
    shaderProgramID = [SampleApplicationShaderUtils createProgramWithVertexShaderFileName:@"Simple.vertsh"
                                                   fragmentShaderFileName:@"Simple.fragsh"];

    if (0 < shaderProgramID) {
        vertexHandle = glGetAttribLocation(shaderProgramID, "vertexPosition");
        normalHandle = glGetAttribLocation(shaderProgramID, "vertexNormal");
        textureCoordHandle = glGetAttribLocation(shaderProgramID, "vertexTexCoord");
        mvpMatrixHandle = glGetUniformLocation(shaderProgramID, "modelViewProjectionMatrix");
        texSampler2DHandle  = glGetUniformLocation(shaderProgramID,"texSampler2D");
    }
    else {
        NSLog(@"Could not initialise augmentation shader");
    }
}


- (void)createFramebuffer
{
    if (context) {
        // Create default framebuffer object
        glGenFramebuffers(1, &defaultFramebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
        
        // Create colour renderbuffer and allocate backing store
        glGenRenderbuffers(1, &colorRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
        
        // Allocate the renderbuffer's storage (shared with the drawable object)
        [context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
        GLint framebufferWidth;
        GLint framebufferHeight;
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &framebufferWidth);
        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &framebufferHeight);
        
        // Create the depth render buffer and allocate storage
        glGenRenderbuffers(1, &depthRenderbuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, depthRenderbuffer);
        glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, framebufferWidth, framebufferHeight);
        
        // Attach colour and depth render buffers to the frame buffer
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderbuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthRenderbuffer);
        
        // Leave the colour render buffer bound so future rendering operations will act on it
        glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    }
}


- (void)deleteFramebuffer
{
    if (context) {
        [EAGLContext setCurrentContext:context];
        
        if (defaultFramebuffer) {
            glDeleteFramebuffers(1, &defaultFramebuffer);
            defaultFramebuffer = 0;
        }
        
        if (colorRenderbuffer) {
            glDeleteRenderbuffers(1, &colorRenderbuffer);
            colorRenderbuffer = 0;
        }
        
        if (depthRenderbuffer) {
            glDeleteRenderbuffers(1, &depthRenderbuffer);
            depthRenderbuffer = 0;
        }
    }
}


- (void)setFramebuffer
{
    // The EAGLContext must be set for each thread that wishes to use it.  Set
    // it the first time this method is called (on the render thread)
    if (context != [EAGLContext currentContext]) {
        [EAGLContext setCurrentContext:context];
    }
    
    if (!defaultFramebuffer) {
        // Perform on the main thread to ensure safe memory allocation for the
        // shared buffer.  Block until the operation is complete to prevent
        // simultaneous access to the OpenGL context
        [self performSelectorOnMainThread:@selector(createFramebuffer) withObject:self waitUntilDone:YES];
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, defaultFramebuffer);
}


- (BOOL)presentFramebuffer
{
    // setFramebuffer must have been called before presentFramebuffer, therefore
    // we know the context is valid and has been set for this (render) thread
    
    // Bind the colour render buffer and present it
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderbuffer);
    
    return [context presentRenderbuffer:GL_RENDERBUFFER];
}


- (double) getCurrentTime
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    double t = tv.tv_sec + tv.tv_usec/1000000.0;
    return t;
}


- (void) animateBowl:(QCAR::Matrix44F*) modelViewMatrix
{
    static float rotateBowlAngle = 0.0f;
    
    static double prevTime = [self getCurrentTime];
    double time = [self getCurrentTime];             // Get real time difference
    float dt = (float)(time-prevTime);          // from frame to frame
    
    rotateBowlAngle += dt * 180.0f/3.1415f;     // Animate angle based on time
    
    SampleApplicationUtils::rotatePoseMatrix(rotateBowlAngle, 0.0f, 1.0f, 0.0f,
                                  &modelViewMatrix->data[0]);
    
    prevTime = time;
}

@end

