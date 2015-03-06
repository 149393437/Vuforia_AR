/*===============================================================================
Copyright (c) 2012-2014 Qualcomm Connected Experiences, Inc. All Rights Reserved.

Vuforia is a trademark of QUALCOMM Incorporated, registered in the United States 
and other countries. Trademarks of QUALCOMM Incorporated are used with permission.
===============================================================================*/

#import "SampleAppAppDelegate.h"
#import "UserDefinedTargetsViewController.h"
#import <QCAR/QCAR.h>
#import <QCAR/TrackerManager.h>
#import <QCAR/ObjectTracker.h>
#import <QCAR/DataSet.h>
#import <QCAR/Trackable.h>
#import <QCAR/CameraDevice.h>

#define TOOLBAR_HEIGHT 53


@interface UserDefinedTargetsViewController ()

@end

@implementation UserDefinedTargetsViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        vapp = [[SampleApplicationSession alloc] initWithDelegate:self];
        
        // Custom initialization
        self.title = @"User Defined Targets";
        // Create the EAGLView with the screen dimensions
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        viewFrame = screenBounds;
        
        // If this device has a retina display, scale the view bounds that will
        // be passed to QCAR; this allows it to calculate the size and position of
        // the viewport correctly when rendering the video background
        if (YES == vapp.isRetinaDisplay) {
            viewFrame.size.width *= 2.0;
            viewFrame.size.height *= 2.0;
        }
        
        tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(autofocus:)];
        tapGestureRecognizer.delegate = self;
        
        refFreeFrame = new RefFreeFrame();
        extendedTrackingIsOn = NO;
    }
    return self;
}
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [tapGestureRecognizer release];
    
    [vapp release];
    [eaglView release];
    delete refFreeFrame;
    
    [super dealloc];
}

-(void) addToolbar
{
    //  Init Toolbar
    CGRect toolbarFrame = CGRectMake(0,
                                     self.view.frame.size.height - TOOLBAR_HEIGHT,
                                     vapp.isRetinaDisplay ? self.view.frame.size.width/2 : self.view.frame.size.width,
                                     TOOLBAR_HEIGHT);
    
    toolbar = [[CustomToolbar alloc] initWithFrame:toolbarFrame];
    toolbar.delegate = self;
    toolbar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;// | UIViewAutoresizingFlexibleWidth;
    
    //  Finally, add toolbar to ViewController's view
    [self.view addSubview:toolbar];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view.superview isKindOfClass:[CustomToolbar class]]) return FALSE;
    return YES;
}

- (void)loadView
{
    // Create the EAGLView
    eaglView = [[UserDefinedTargetsEAGLView alloc] initWithFrame:viewFrame appSession:vapp];
    [eaglView setRefFreeFrame: refFreeFrame];
    [self setView:eaglView];
    SampleAppAppDelegate *appDelegate = (SampleAppAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = eaglView;
    
    CGRect mainBounds = [[UIScreen mainScreen] bounds];
    CGRect indicatorBounds = CGRectMake(mainBounds.size.width / 2 - 12,
                                        mainBounds.size.height / 2 - 12, 24, 24);
    UIActivityIndicatorView *loadingIndicator = [[[UIActivityIndicatorView alloc]
                                          initWithFrame:indicatorBounds]autorelease];
    
    loadingIndicator.tag  = 1;
    loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [eaglView addSubview:loadingIndicator];
    [loadingIndicator startAnimating];
    
    // we use the iOS notification to pause/resume the AR when the application goes (or comeback from) background
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(pauseAR)
     name:UIApplicationWillResignActiveNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(resumeAR)
     name:UIApplicationDidBecomeActiveNotification
     object:nil];

    //  Add bottom toolbar
    [self addToolbar];
    refFreeFrame->stopImageTargetBuilder();


    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(goodFrameQuality:)
                                                 name:@"kGoodFrameQuality"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(badFrameQuality:)
                                                 name:@"kBadFrameQuality"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(trackableCreated:)
                                                 name:@"kTrackableCreated"
                                               object:nil];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [vapp initAR:QCAR::GL_20 ARViewBoundsSize:viewFrame.size orientation:UIInterfaceOrientationPortrait];
}

- (void) pauseAR {
    NSError * error = nil;
    if (![vapp pauseAR:&error]) {
        NSLog(@"Error pausing AR:%@", [error description]);
    }
}

- (void) resumeAR {
    NSError * error = nil;
    if(! [vapp resumeAR:&error]) {
        NSLog(@"Error resuming AR:%@", [error description]);
    }
    // on resume, we reset the flash and the associated menu item
    QCAR::CameraDevice::getInstance().setFlashTorchMode(false);
    SampleAppMenu * menu = [SampleAppMenu instance];
    [menu setSelectionValueForCommand:C_FLASH value:false];
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    [self prepareMenu];

  // Do any additional setup after loading the view.
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.view addGestureRecognizer:tapGestureRecognizer];
    
    NSLog(@"self.navigationController.navigationBarHidden: %s", self.navigationController.navigationBarHidden ? "Yes" : "No");
}

- (void)viewWillDisappear:(BOOL)animated {
    // cleanup menu
    [[SampleAppMenu instance]clear];

    refFreeFrame->deInit();
    [vapp stopAR:nil];
    // Be a good OpenGL ES citizen: now that QCAR is paused and the render
    // thread is not executing, inform the root view controller that the
    // EAGLView should finish any OpenGL ES commands
    [eaglView finishOpenGLESCommands];

    SampleAppAppDelegate *appDelegate = (SampleAppAppDelegate*)[[UIApplication sharedApplication] delegate];
    appDelegate.glResourceHandler = nil;

    [super viewWillDisappear:animated];
}

- (void)finishOpenGLESCommands
{
    // Called in response to applicationWillResignActive.  Inform the EAGLView
    [eaglView finishOpenGLESCommands];
}


- (void)freeOpenGLESResources
{
    // Called in response to applicationDidEnterBackground.  Inform the EAGLView
    [eaglView freeOpenGLESResources];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    // Portrait only
    return toInterfaceOrientation == UIInterfaceOrientationPortrait;
}

// Not using iOS6 specific enums in order to compile on iOS5 and lower versions
-(NSUInteger)supportedInterfaceOrientations
{
    // Portrait only
    return (1 << UIInterfaceOrientationPortrait);
}

-(void)setCameraMode
{
    refFreeFrame->startImageTargetBuilder();
    
    toolbar.isCancelButtonHidden = YES;
    toolbar.shouldRotateActionButton = YES;
    toolbar.actionImage = [UIImage imageNamed:@"icon_camera.png"];
}

#pragma mark - Notifications
- (void)goodFrameQuality:(NSNotification *)aNotification
{
    //NSLog(@">> goodFrameQuality");
}

- (void)badFrameQuality:(NSNotification *)aNotification
{
    //NSLog(@">> badFrameQuality");
}

- (void)trackableCreated:(NSNotification *)aNotification
{
    // we restart the camera mode once a target has been added
    [self setCameraMode];
}

#pragma mark - CustomToolbarDelegateProtocol

-(void)actionButtonWasPressed
{
    //  Camera button was pressed
    if (refFreeFrame->isImageTargetBuilderRunning() == YES)
    {
        refFreeFrame->startBuild();
    }
}

-(void)cancelButtonWasPressed
{
    // No cancel button
}



#pragma mark - SampleApplicationControl

// Initialize the application trackers        
- (bool) doInitTrackers {
    // Initialize the image tracker
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* trackerBase = trackerManager.initTracker(QCAR::ObjectTracker::getClassType());
    if (trackerBase == NULL)
    {
        NSLog(@"Failed to initialize ObjectTracker.");
        return false;
    }
    return true;
}

// load the data associated to the trackers
- (bool) doLoadTrackersData {
    // Get the image tracker:
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ObjectTracker* objectTracker = static_cast<QCAR::ObjectTracker*>(trackerManager.getTracker(QCAR::ObjectTracker::getClassType()));
    if (objectTracker != nil)
    {
        // Create the data set:
        dataSetUserDef = objectTracker->createDataSet();
        if (dataSetUserDef != nil)
        {
            if (!objectTracker->activateDataSet(dataSetUserDef))
            {
                NSLog(@"Failed to activate data set.");
                return false;
            }
        }
    }
    return true;
}

// start the application trackers
- (bool) doStartTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::ObjectTracker::getClassType());
    if(tracker == 0) {
        return false;
    }
    
    tracker->start();
    return true;
}

// callback called when the initailization of the AR is done
- (void) onInitARDone:(NSError *)initError {
    UIActivityIndicatorView *loadingIndicator = (UIActivityIndicatorView *)[eaglView viewWithTag:1];
    [loadingIndicator removeFromSuperview];
    
    if (initError == nil) {
        NSError * error = nil;
        
        [self setCameraMode];

        [vapp startAR:QCAR::CameraDevice::CAMERA_BACK error:&error];
        
        // by default, we try to set the continuous auto focus mode
        // and we update menu to reflect the state of continuous auto-focus
        bool isContinuousAutofocus = QCAR::CameraDevice::getInstance().setFocusMode(QCAR::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO);
        SampleAppMenu * menu = [SampleAppMenu instance];
        [menu setSelectionValueForCommand:C_AUTOFOCUS value:isContinuousAutofocus];

    } else {
        NSLog(@"Error initializing AR:%@", [initError description]);
        
        dispatch_async( dispatch_get_main_queue(), ^{
            
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                            message:[initError localizedDescription]
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            [alert release];
        });
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kMenuDismissViewController" object:nil];
}

// update from the QCAR loop
- (void) onQCARUpdate: (QCAR::State *) state {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ObjectTracker* objectTracker = static_cast<QCAR::ObjectTracker*>(trackerManager.getTracker(QCAR::ObjectTracker::getClassType()));
    
    if(refFreeFrame->hasNewTrackableSource())
    {
        QCAR::Trackable * lastCreated;
        
        NSLog(@"Attempting to transfer the trackable source to the dataset");
        
        // Deactiveate current dataset
        objectTracker->deactivateDataSet(objectTracker->getActiveDataSet());
        
        // Clear the oldest target if the dataset is full or the dataset
        // already contains five user-defined targets.
        if (dataSetUserDef->hasReachedTrackableLimit()
            || dataSetUserDef->getNumTrackables() >= 5)
            dataSetUserDef->destroy(dataSetUserDef->getTrackable(0));
        
        // if extended tracking is on, we need to stop the extended tracking on the
        // last trackable first as extended tracking should only be enable on one trackable
        if ((extendedTrackingIsOn) && (dataSetUserDef->getNumTrackables() > 0)) {
            lastCreated = dataSetUserDef->getTrackable(dataSetUserDef->getNumTrackables() - 1);
            lastCreated->stopExtendedTracking();
            objectTracker->resetExtendedTracking();
        }
        
        // Add new trackable source
        lastCreated = dataSetUserDef->createTrackable(refFreeFrame->getNewTrackableSource());
        
        // if extended tracking is on we activate it on this newly created trackable
        if (extendedTrackingIsOn) {
            lastCreated->startExtendedTracking();
        }
        
        
        // Reactivate current dataset
        objectTracker->activateDataSet(dataSetUserDef);

    }
    

}

// stop your trackerts
- (bool) doStopTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::Tracker* tracker = trackerManager.getTracker(QCAR::ObjectTracker::getClassType());
    
    if (NULL == tracker) {
        NSLog(@"ERROR: failed to get the tracker from the tracker manager");
        return false;
    }
    tracker->stop();
    return true;
}

// unload the data associated to your trackers
- (bool) doUnloadTrackersData {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    QCAR::ObjectTracker* objectTracker = static_cast<QCAR::ObjectTracker*>(trackerManager.getTracker(QCAR::ObjectTracker::getClassType()));
    if (objectTracker == NULL)
    {
        NSLog(@"Failed to destroy the tracking data set because the ObjectTracker has not been initialized.");
        return false;
    }
    
    if (dataSetUserDef != nil)
    {
        if (objectTracker->getActiveDataSet() && !objectTracker->deactivateDataSet(dataSetUserDef))
        {
            NSLog(@"Failed to destroy the tracking data set because the data set could not be deactivated.");
            return false;
        }
        if (!objectTracker->destroyDataSet(dataSetUserDef))
        {
            NSLog(@"Failed to destroy the tracking data set.");
            return false;
        }
    }
    extendedTrackingIsOn = NO;
    dataSetUserDef = nil;
    return true;
}

// deinitialize your trackers
- (bool) doDeinitTrackers {
    QCAR::TrackerManager& trackerManager = QCAR::TrackerManager::getInstance();
    trackerManager.deinitTracker(QCAR::ObjectTracker::getClassType());
    return true;
}

- (void)autofocus:(UITapGestureRecognizer *)sender
{
    [self performSelector:@selector(cameraPerformAutoFocus) withObject:nil afterDelay:.4];
}

- (void)cameraPerformAutoFocus
{
    QCAR::CameraDevice::getInstance().setFocusMode(QCAR::CameraDevice::FOCUS_MODE_TRIGGERAUTO);
}

- (BOOL) setExtendedTrackingForDataSet:(QCAR::DataSet *)theDataSet start:(BOOL) start {
    BOOL result = YES;
    
    if (dataSetUserDef->getNumTrackables() > 0) {
        QCAR::Trackable* trackable = dataSetUserDef->getTrackable(dataSetUserDef->getNumTrackables() - 1);
        if (start) {
            if(! trackable->startExtendedTracking()) {
                NSLog(@"Failed to start extended tracking on: %s", trackable->getName());
                result = false;
            }
        } else {
            if (!trackable->stopExtendedTracking())
            {
                NSLog(@"Failed to stop extended tracking on: %s", trackable->getName());
                result = false;
            }
        }
    }
    return result;
}
    
    

#pragma mark - left menu

typedef enum {
    C_EXTENDED_TRACKING,
    C_AUTOFOCUS,
    C_FLASH,
    C_CAMERA_FRONT,
    C_CAMERA_REAR
} MENU_COMMAND;

- (void) prepareMenu {
    
    SampleAppMenu * menu = [SampleAppMenu prepareWithCommandProtocol:self title:@"User Defined Targets"];
    SampleAppMenuGroup * group;
    
    group = [menu addGroup:@""];
    [group addTextItem:@"Vuforia Samples" command:-1];

    group = [menu addGroup:@""];
    [group addSelectionItem:@"Extended Tracking" command:C_EXTENDED_TRACKING isSelected:NO];
    [group addSelectionItem:@"Autofocus" command:C_AUTOFOCUS isSelected:NO];
    [group addSelectionItem:@"Flash" command:C_FLASH isSelected:NO];

    group = [menu addSelectionGroup:@"CAMERA"];
    [group addSelectionItem:@"Front" command:C_CAMERA_FRONT isSelected:NO];
    [group addSelectionItem:@"Rear" command:C_CAMERA_REAR isSelected:YES];
}

- (bool) menuProcess:(SampleAppMenu *) menu command:(int) command value:(bool) value{
    bool result = true;
    NSError * error = nil;

    switch(command) {
        case C_FLASH:
            if (!QCAR::CameraDevice::getInstance().setFlashTorchMode(value)) {
                result = false;
            }
            break;
        
        case C_EXTENDED_TRACKING:
            result = [self setExtendedTrackingForDataSet:dataSetUserDef start:value];
            if (result) {
                [eaglView setOffTargetTrackingMode:value];
                // we keep track of the state of the extended tracking mode
                extendedTrackingIsOn = value;
            }
        break;
        
        
        case C_CAMERA_FRONT:
        case C_CAMERA_REAR: {
            if ([vapp stopCamera:&error]) {
                result = [vapp startAR:(command == C_CAMERA_FRONT) ? QCAR::CameraDevice::CAMERA_FRONT:QCAR::CameraDevice::CAMERA_BACK error:&error];
            } else {
                result = false;
            }
            if (result) {
                // if the camera switch worked, the flash will be off
                [menu setSelectionValueForCommand:C_FLASH value:false];
            }

        }
            break;
            
        case C_AUTOFOCUS: {
            int focusMode = (YES == value) ? QCAR::CameraDevice::FOCUS_MODE_CONTINUOUSAUTO : QCAR::CameraDevice::FOCUS_MODE_NORMAL;
            result = QCAR::CameraDevice::getInstance().setFocusMode(focusMode);
        }
            break;
            
        default:
            result = false;
            break;
    }
    return result;
}

@end

